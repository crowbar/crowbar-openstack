# Copyright 2011, Dell 
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

class KongService < ServiceObject

  def initialize(thelogger)
    @bc_name = "kong"
    @logger = thelogger
  end

  def create_proposal
    @logger.debug("Kong create_proposal: entering")
    base = super
    @logger.debug("Kong create_proposal: leaving base part")

    nodes = NodeObject.find("roles:nova-multi-controller")
    nodes.delete_if { |n| n.nil? or n.admin? }
    unless nodes.empty?
      base["deployment"]["kong"]["elements"] = {
        "kong" => [ nodes.first.name ]
      }
    end

    @logger.debug("Kong create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Kong apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    # Update tempest_tarball path
    nodes = NodeObject.find("roles:provisioner-server")
    unless nodes.nil? or nodes.length < 1
      admin_ip = nodes[0].get_network_by_type("admin")["address"]
      web_port = nodes[0]["provisioner"]["web_port"]
      # substitute the admin web portal
      tempest_tarball_path = role.default_attributes["kong"]["tempest_tarball"].gsub("<ADMINWEB>", "#{admin_ip}:#{web_port}")
      role.default_attributes["kong"]["tempest_tarball"] = tempest_tarball_path
      role.save
    end

    @logger.debug("Kong apply_role_pre_chef_call: leaving")
  end

end

