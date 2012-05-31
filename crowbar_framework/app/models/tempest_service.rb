# Copyright 2011, Dell 
# Copyright 2012, Dell
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

class TempestService < ServiceObject

  def initialize(thelogger)
    @bc_name = "tempest"
    @logger = thelogger
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "nova", "inst" => role.default_attributes["tempest"]["nova_instance"] }
    answer
  end

  def create_proposal
    @logger.debug("Tempest create_proposal: entering")
    base = super
    @logger.debug("Tempest create_proposal: leaving base part")

    nodes = NodeObject.find("roles:nova-multi-controller")
    nodes.delete_if { |n| n.nil? or n.admin? }
    unless nodes.empty?
      base["deployment"]["tempest"]["elements"] = {
        "tempest" => [ nodes.first.name ]
      }
    end

    base["attributes"]["tempest"]["nova_instance"] = ""
    begin
      novaService = NovaService.new(@logger)
      novas = novaService.list_active[1]
      if novas.empty?
        # No actives, look for proposals
        novas = novaService.proposals[1]
      end
      base["attributes"]["tempest"]["nova_instance"] = novas[0] unless novas.empty?
    rescue
      @logger.info("Tempest create_proposal: no nova found")
    end

    @logger.debug("Tempest create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Tempest apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    role.default_attributes["tempest"]["alt_userpass"] = random_password if role.default_attributes["tempest"]["alt_userpass"].nil?

    # Update tempest_tarball path
    nodes = NodeObject.find("roles:provisioner-server")
    unless nodes.nil? or nodes.length < 1
      admin_ip = nodes[0].get_network_by_type("admin")["address"]
      web_port = nodes[0]["provisioner"]["web_port"]
      # substitute the admin web portal
      tempest_tarball_path = role.default_attributes["tempest"]["tempest_tarball"].gsub("<ADMINWEB>", "#{admin_ip}:#{web_port}")
      role.default_attributes["tempest"]["tempest_tarball"] = tempest_tarball_path
    end

    role.save

    @logger.debug("Tempest apply_role_pre_chef_call: leaving")
  end

end

