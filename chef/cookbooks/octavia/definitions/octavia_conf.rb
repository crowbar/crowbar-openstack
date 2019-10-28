# Copyright 2019, SUSE LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

define :octavia_conf do
  amphora = node[:octavia][:amphora]
  net_name = amphora[:manage_net]
  old_amp = if node[:octavia][:old_amphora].nil?
    {}
  else
    node[:octavia][:old_amphora]
  end

  ruby_block "Check for amphora changes" do
    block do
      if node[:octavia][:sec_group_id].nil? || amphora[:sec_group] != old_amp[:sec_group]
        node.set[:octavia][:sec_group_id] = shell_out("#{params[:cmd]} security group show "\
                                                      "#{amphora[:sec_group]} "\
                                                      "-f value -c id").stdout.delete "\n"
      end
      if node[:octavia][:flavor_id].nil? || amphora[:flavor] != old_amp[:flavor]
        node.set[:octavia][:flavor_id] =  shell_out("#{params[:cmd]} flavor show "\
                                                    "#{amphora[:flavor]}" \
                                                    " -f value -c id").stdout.delete "\n"
      end
      if node[:octavia][:net_id].nil? || net_name != old_amp[:manage_net]
        node.set[:octavia][:net_id] = shell_out("#{params[:cmd]} network show #{net_name} "\
                                                "-f value -c id").stdout.delete "\n"
      end
    end
  end

  conf_files = OctaviaHelper.conf_file(params[:name])
  conf_files.each do |conf_file|
    template conf_file do
      source "#{File.basename(conf_file)}.erb"
      owner node[:octavia][:user]
      group node[:octavia][:group]
      mode 0o640
      variables(
        lazy do
          {
            bind_host: OctaviaHelper.bind_host(node, params[:name]),
            bind_port: OctaviaHelper.bind_port(node, params[:name]),
            octavia_db_connection: fetch_database_connection_string(node[:octavia][:db]),
            neutron_endpoint: OctaviaHelper.get_neutron_endpoint(node),
            nova_endpoint: OctaviaHelper.get_nova_endpoint(node),
            octavia_keystone_settings: KeystoneHelper.keystone_settings(node, "octavia"),
            rabbit_settings: fetch_rabbitmq_settings,
            octavia_nova_flavor_id: node[:octavia][:flavor_id],
            octavia_mgmt_net_id: node[:octavia][:net_id],
            octavia_mgmt_sec_group_id: node[:octavia][:sec_group_id],
            octavia_healthmanager_hosts: OctaviaHelper.get_healthmanager_nodes(node, net_name)
          }
        end
      )
    end
  end
end
