#
# Cookbook Name:: ceilometer
# Library:: mongodb
#
# Copyright 2014, SUSE Linux GmbH
# Copyright 2011, edelight GmbH
# Authors:
# Markus Korn <markus.korn@edelight.de>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# original at: https://github.com/edelight/chef-mongodb/blob/master/libraries/mongodb.rb

require "json"
include Chef::Mixin::ShellOut

module CeilometerHelper
  class << self
    def replica_set_members(node)
      CrowbarUtilsSearch.node_search_with_cache(node,
                                                "roles:ceilometer-server",
                                                "ceilometer").select do |n|
        n[:ceilometer][:ha][:mongodb][:replica_set][:member] rescue false
      end
    end

    def mongodb_connection_string(node)
      connection_string = nil

      if node[:ceilometer][:ha][:server][:enabled]
        db_hosts = replica_set_members(node)
        unless db_hosts.empty?
          mongodb_servers = db_hosts.map do |s|
            address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(s, "admin").address
            port = s[:ceilometer][:mongodb][:port]
            "#{address}:#{port}"
          end
          mongodb_servers_list = mongodb_servers.sort.join(",")
          replica_set_name = node[:ceilometer][:ha][:mongodb][:replica_set][:name]

          connection_string = \
            "mongodb://#{mongodb_servers_list}/ceilometer?replicaSet=#{replica_set_name}"
        end
      end

      # if this is a cluster, but the replica set member attribute hasn't
      # been set on any node (yet), we just fallback to using the first
      # ceilometer-server node
      if connection_string.nil?
        db_hosts = CrowbarUtilsSearch.node_search_with_cache(
          node,
          "roles:ceilometer-server",
          "ceilometer"
        )
        db_host = db_hosts.first || node
        address = Chef::Recipe::Barclamp::Inventory.get_network_by_type(db_host, "admin").address
        port = db_host[:ceilometer][:mongodb][:port]
        connection_string = "mongodb://#{address}:#{port}/ceilometer"
      end

      connection_string
    end

    def configure_replicaset(node, name, members)
      # lazy require, to move loading this modules to runtime of the cookbook
      require "rubygems"
      begin
        require "mongo"
      rescue LoadError
        # After installation of the gem, we have a new path for the new gem, so
        # we need to reset the paths if we can't load rubygem-mongo
        Gem.clear_paths
        require "mongo"
      end

      if members.length == 0
        if Chef::Config[:solo]
          abort("Cannot configure replicaset '#{name}', no member nodes found")
        else
          Chef::Log.warn("Cannot configure replicaset '#{name}', no member nodes found")
          return
        end
      end

      begin
        connection = nil
        rescue_connection_failure do
          connection = Mongo::Connection.new(node.fqdn, node[:ceilometer][:ha][:mongodb][:port], op_timeout: 5, slave_ok: true)
          connection.database_names # check connection
        end
      rescue => e
        Chef::Log.warn("Could not connect to database: '#{node.fqdn}', reason: #{e}")
        return
      end

      # Want the node originating the connection to be included in the replicaset
      members << node unless members.any? { |m| m.name == node.name }
      members.sort! { |x, y| x.name <=> y.name }
      rs_members = []
      rs_options = {}
      members.each_index do |n|
        host = "#{members[n].address.addr}:#{members[n][:ceilometer][:mongodb][:port]}"
        rs_options[host] = {}
        rs_members << { "_id" => n, "host" => host }.merge(rs_options[host])
      end

      Chef::Log.info(
        "Configuring replicaset with members #{members.map { |n| n['hostname'] }.join(', ')}"
        )

      rs_member_ips = []
      members.each_index do |n|
        # port = members[n]['mongodb']['config']['port']
        rs_member_ips << { "_id" => n, "host" => "#{members[n]['ipaddress']}:#{members[n][:ceilometer][:mongodb][:port]}" }
      end

      admin = connection["admin"]
      cmd = BSON::OrderedHash.new
      cmd["replSetInitiate"] = {
        "_id" => name,
        "members" => rs_members
      }

      begin
        result = admin.command(cmd, check_response: false)
      rescue Mongo::OperationTimeout
        Chef::Log.info("Started configuring the replicaset, this will take some time, another run should run smoothly")
        return
      end
      if result.fetch("ok", nil) == 1
        # everything is fine, do nothing
      elsif result.fetch("errmsg", nil) =~ /(\S+) is already initiated/ || (result.fetch("errmsg", nil) == "already initialized")
        server, port = Regexp.last_match.nil? || Regexp.last_match.length < 2 ? [node.address.addr, node[:ceilometer][:mongodb][:port]] : Regexp.last_match[1].split(":")
        begin
          connection = Mongo::Connection.new(server, port, op_timeout: 5, slave_ok: true)
        rescue
          abort("Could not connect to database: '#{server}:#{port}'")
        end

        # check if both configs are the same
        config = connection["local"]["system"]["replset"].find_one("_id" => name)

        if config["_id"] == name && config["members"] == rs_members
          # config is up-to-date, do nothing
          Chef::Log.info("Replicaset '#{name}' already configured")
        elsif config["_id"] == name && config["members"] == rs_member_ips
          # config is up-to-date, but ips are used instead of hostnames, change config to hostnames
          Chef::Log.info("Need to convert ips to hostnames for replicaset '#{name}'")
          old_members = config["members"].map { |m| m["host"] }
          mapping = {}
          rs_member_ips.each do |mem_h|
            members.each do |n|
              ip, prt = mem_h["host"].split(":")
              mapping["#{ip}:#{prt}"] = "#{n.address.addr}:#{prt}" if ip == n["ipaddress"]
            end
          end
          config["members"].map! do |m|
            host = mapping[m["host"]]
            { "_id" => m["_id"], "host" => host }.merge(rs_options[host])
          end
          config["version"] += 1

          rs_connection = nil
          rescue_connection_failure do
            rs_connection = Mongo::ReplSetConnection.new(old_members)
            rs_connection.database_names # check connection
          end

          admin = rs_connection["admin"]
          cmd = BSON::OrderedHash.new
          cmd["replSetReconfig"] = config
          result = nil
          begin
            result = admin.command(cmd, check_response: false)
          rescue Mongo::ConnectionFailure
            # reconfiguring destroys existing connections, reconnect
            connection = Mongo::Connection.new(node.address.addr, node[:ceilometer][:mongodb][:port], op_timeout: 5, slave_ok: true)
            config = connection["local"]["system"]["replset"].find_one("_id" => name)
            # Validate configuration change
            if config["members"] == rs_members
              Chef::Log.info("New config successfully applied: #{config.inspect}")
            else
              Chef::Log.error("Failed to apply new config. Current config: #{config.inspect} Target config #{rs_members}")
              return
            end
          end
          Chef::Log.error("configuring replicaset returned: #{result.inspect}") unless result.fetch("errmsg", nil).nil?
        else
          # remove removed members from the replicaset and add the new ones
          max_id = config["members"].map { |member| member["_id"] }.max
          rs_members.map! { |member| member["host"] }
          config["version"] += 1
          old_members = config["members"].map { |member| member["host"] }
          members_delete = old_members - rs_members
          config["members"] = config["members"].delete_if { |m| members_delete.include?(m["host"]) }
          config["members"].map! do |m|
            host = m["host"]
            { "_id" => m["_id"], "host" => host }.merge(rs_options[host])
          end
          members_add = rs_members - old_members
          members_add.each do |m|
            max_id += 1
            config["members"] << { "_id" => max_id, "host" => m }.merge(rs_options[m])
          end

          rs_connection = nil
          rescue_connection_failure do
            rs_connection = Mongo::ReplSetConnection.new(old_members)
            rs_connection.database_names # check connection
          end

          admin = rs_connection["admin"]

          cmd = BSON::OrderedHash.new
          cmd["replSetReconfig"] = config

          result = nil
          begin
            result = admin.command(cmd, check_response: false)
          rescue Mongo::ConnectionFailure
            # reconfiguring destroys existing connections, reconnect
            connection = Mongo::Connection.new(node.address.addr, node[:ceilometer][:mongodb][:port], op_timeout: 5, slave_ok: true)
            config = connection["local"]["system"]["replset"].find_one("_id" => name)
            # Validate configuration change
            if config["members"] == rs_members
              Chef::Log.info("New config successfully applied: #{config.inspect}")
            else
              Chef::Log.error("Failed to apply new config. Current config: #{config.inspect} Target config #{rs_members}")
              return
            end
          end
          Chef::Log.error("configuring replicaset returned: #{result.inspect}") unless result.nil? || result.fetch("errmsg", nil).nil?
        end
      elsif !result.fetch("errmsg", nil).nil?
        Chef::Log.error("Failed to configure replicaset, reason: #{result.inspect}, tried command: #{cmd}")
      end
    end

    # Ensure retry upon failure
    def rescue_connection_failure(max_retries = 30)
      retries = 0
      begin
        yield
      rescue Mongo::ConnectionFailure => ex
        retries += 1
        raise ex if retries > max_retries
        sleep(0.5)
        retry
      end
    end
  end
end

