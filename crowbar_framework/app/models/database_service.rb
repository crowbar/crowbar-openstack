# Copyright 2012, SUSE Linux Proucts GmbH 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 

class DatabaseService < ServiceObject

  def initialize(thelogger)
    @bc_name = "database"
    @logger = thelogger
  end

# turn off nulti proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  def create_proposal
    @logger.debug("Database create_proposal: entering")
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    if nodes.size >= 1
      base["deployment"]["database"]["elements"] = {
        "database-server" => [ nodes.first[:fqdn] ]
      }
    end

    @logger.debug("Database create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Database apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    # Make sure the bind hosts are in the admin network
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n

      admin_address = node.get_network_by_type("admin")["address"]
      node.crowbar[:database] = {} if node.crowbar[:database].nil?
      node.crowbar[:database][:api_bind_host] = admin_address
      @logger.debug("Database api bind host: #{node.crowbar[:database][:api_bind_host]}")
      node.save
    end

    sql_engine = role.default_attributes["database"]["sql_engine"]
    role.default_attributes["database"][sql_engine] = {} if role.default_attributes["database"][sql_engine].nil?
    role.default_attributes["database"]["db_maker_password"] = (old_role && old_role.default_attributes["database"]["db_maker_password"]) || random_password

    if ( sql_engine == "mysql" )
      role.default_attributes["database"]["mysql"]["server_debian_password"] = (old_role && old_role.default_attributes["database"]["mysql"]["server_debian_password"]) || random_password
      role.default_attributes["database"]["mysql"]["server_root_password"] = (old_role && old_role.default_attributes["database"]["mysql"]["server_root_password"]) || random_password
      role.default_attributes["database"]["mysql"]["server_repl_password"] = (old_role && old_role.default_attributes["database"]["mysql"]["server_repl_password"]) || random_password
      @logger.debug("setting mysql specific attributes")
    end

    # Copy the attributes for database/<sql_engine> to <sql_engine> in the
    # role attributes to avoid renaming all attributes everywhere in the
    # postgres and mysql cookbooks
    # (FIXME: is there a better way to achieve this?)
    role.default_attributes[sql_engine] = role.default_attributes["database"][sql_engine]
    role.save

    @logger.debug("Database apply_role_pre_chef_call: leaving")
  end

end

