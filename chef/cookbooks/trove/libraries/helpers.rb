#
# Copyright 2016, SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef
  class Recipe
    def get_sql_connection
      # get Database data
      db_password = ""
      if node.roles.include? "trove-server"
        db_password = node[:trove][:db][:password]
      else
        # pickup password to database from trove-server node
        node_servers = search_env_filtered(:node, "roles:trove-server")
        if node_servers.length > 0
          db_password = node_servers[0][:trove][:db][:password]
        end
      end
      # FIXME: trove uses mysql and the mysql server is currently always
      # running on the same node
      "mysql://#{node[:trove][:db][:user]}:"\
      "#{db_password}@127.0.0.1/"\
      "#{node[:trove][:db][:database]}"
    end

    def get_rabbitmq_trove_settings
      # get rabbitmq-server information
      # NOTE: Trove uses it's own vhost instead of the default one
      rabbitmq_servers = search_env_filtered(:node, "roles:rabbitmq-server")
      unless rabbitmq_servers.empty?
        rabbitmq_trove_settings = rabbitmq_servers[0][:rabbitmq][:trove]
      else
        rabbitmq_trove_settings = nil
      end
      rabbitmq_trove_settings
    end

    def get_nova_details
      # get nova information
      nova_controllers = search_env_filtered(:node, "roles:nova-controller")
      unless nova_controllers.empty?
        nova = nova_controllers[0]
        keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name)
        nova_api_host = CrowbarHelper.get_host_for_admin_url(
          nova, (nova[:nova][:ha][:enabled] rescue false))
        nova_api_protocol = nova[:nova][:ssl][:enabled] ? "https" : "http"
        nova_url = "#{nova_api_protocol}://#{nova_api_host}:#{nova[:nova][:ports][:api]}/v2/"
        nova_insecure = keystone_settings["insecure"] || (
          nova[:nova][:ssl][:enabled] && nova[:nova][:ssl][:insecure]
        )
      else
        nova_url = nil
        nova_insecure = false
      end
      [nova_url, nova_insecure]
    end

    def get_cinder_details
      # get cinder information
      cinder_controllers = search_env_filtered(:node, "roles:cinder-controller")
      unless cinder_controllers.empty?
        cinder = cinder_controllers[0]
        cinder_api_host = CrowbarHelper.get_host_for_admin_url(
          cinder, (cinder[:cinder][:ha][:enabled] rescue false)
        )
        cinder_api_protocol = cinder[:cinder][:ssl][:enabled] ? "https" : "http"
        cinder_port = cinder[:cinder][:api][:bind_port]
        cinder_url = "#{cinder_api_protocol}://#{cinder_api_host}:#{cinder_port}/v1/"
        cinder_insecure = cinder[:cinder][:api][:protocol] == "https" &&
                          cinder[:cinder][:ssl][:insecure]
      else
        cinder_url = nil
        cinder_insecure = false
      end
      [cinder_url, cinder_insecure]
    end

    def get_objectstore_details
      # get swift information
      swift_proxies = search_env_filtered(:node, "roles:swift-proxy")
      unless swift_proxies.empty?
        swift = swift_proxies[0]
        swift_api_host = CrowbarHelper.get_host_for_admin_url(
          swift, (swift[:swift][:ha][:enabled] rescue false)
        )
        swift_api_protocol = swift[:swift][:ssl][:enabled] ? "https" : "http"
        swift_api_port = swift[:swift][:ports][:api]
        object_store_url = "#{swift_api_protocol}://#{swift_api_host}:#{swift_api_port}/v1/"
        object_store_insecure = swift["swift"]["ssl"]["insecure"]
      else
        # maybe radosgw instead of swift?
        ceph_radosgws = search_env_filtered(:node, "roles:ceph-radosgw")
        unless ceph_radosgws.empty?
          radosgw = ceph_radosgws[0]
          radosgw_api_host = CrowbarHelper.get_host_for_admin_url(
            radosgw, (radosgw[:ceph][:ha][:radosgw][:enabled] rescue false)
          )
          radosgw_api_protocol = radosgw[:ceph][:radosgw][:ssl][:enabled] ? "https" : "http"
          if radosgw[:ceph][:radosgw][:ssl][:enabled]
            radosgw_api_port =  node[:ceph][:radosgw][:rgw_port_ssl]
          else
            radosgw_api_port = node[:ceph][:radosgw][:rgw_port]
          end
          object_store_url = "#{radosgw_api_protocol}://#{radosgw_api_host}:#{radosgw_api_port}/swift/v1"
          object_store_insecure = radosgw[:ceph][:radosgw][:ssl][:insecure]
        else
          object_store_url = nil
          object_store_insecure = false
        end
        [object_store_url, object_store_insecure]
      end
    end
  end
end
