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

class QuantumService < ServiceObject

  def initialize(thelogger)
    @bc_name = "quantum"
    @logger = thelogger
  end

  def self.allow_multiple_proposals?
    true
  end

  def proposal_dependencies(role)
    answer = []
    if role.default_attributes["quantum"]["sql_engine"] == "mysql"
      answer << { "barclamp" => "mysql", "inst" => role.default_attributes["quantum"]["mysql_instance"] }
    end
    if role.default_attributes["quantum"]["use_gitrepo"]
      answer << { "barclamp" => "git", "inst" => role.default_attributes["quantum"]["git_instance"] }
    end
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["quantum"]["keystone_instance"] }
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"][@bc_name]["git_instance"] = ""
    begin
      gitService = GitService.new(@logger)
      gits = gitService.list_active[1]
      if gits.empty?
        # No actives, look for proposals
        gits = gitService.proposals[1]
      end
      unless gits.empty?
        base["attributes"]["quantum"]["git_instance"] = gits[0]
      end
    rescue
      @logger.info("#{@bc_name} create_proposal: no git found")
    end


    base["attributes"]["quantum"]["mysql_instance"] = ""
    begin
      mysqlService = MysqlService.new(@logger)
      # Look for active roles
      mysqls = mysqlService.list_active[1]
      if mysqls.empty?
        # No actives, look for proposals
        mysqls = mysqlService.proposals[1]
      end
      if mysqls.empty?
        base["attributes"]["quantum"]["sql_engine"] = "sqlite"
      else
        base["attributes"]["quantum"]["mysql_instance"] = mysqls[0]
        base["attributes"]["quantum"]["sql_engine"] = "mysql"
      end
    rescue
      @logger.info("Quantumcreate_proposal: no mysql found")
      base["attributes"]["quantum"]["sql_engine"] = "sqlite"
    end
    
    base["deployment"]["quantum"]["elements"] = {
        "quantum-server" => [ nodes.first[:fqdn] ]
    } unless nodes.nil? or nodes.length ==0

    base[:attributes][:quantum][:service][:token] = '%012d' % rand(1e12)
    base["attributes"]["quantum"]["service_password"] = '%012d' % rand(1e12)

    insts = ["Keystone"]

    insts.each do |inst|
      base["attributes"][@bc_name]["#{inst.downcase}_instance"] = ""
      begin
        instService = eval "#{inst}Service.new(@logger)"
        instes = instService.list_active[1]
        if instes.empty?
          # No actives, look for proposals
          instes = instService.proposals[1]
        end
        base["attributes"][@bc_name]["#{inst.downcase}_instance"] = instes[0] unless instes.empty?
      rescue
        @logger.info("#{@bc_name} create_proposal: no #{inst.downcase} found")
      end
    end


    base
  end




  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Quantum apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    net_svc = NetworkService.new @logger

    tnodes = role.override_attributes["quantum"]["elements"]["quantum-server"]
    #tnodes = all_nodes if role.default_attributes["nova"]["network"]["ha_enabled"]
    unless tnodes.nil? or tnodes.empty?
      tnodes.each do |n|
        net_svc.enable_interface "default", "nova_fixed", n
        cnode = NodeObject.find_node_by_name n
        #even if crowbar bring up the single iface it keep cfg for both and since no one care even about sorting elements from this cfg we facing randomely bringing up-down-reconfigure-etc ifaces so lets just try not to deal with this problem
        if cnode[:network][:networks]["nova_floating"]["conduit"]==cnode[:network][:networks]["public"]["conduit"] and cnode[:network][:networks]["nova_floating"]["vlan"]==cnode[:network][:networks]["public"]["vlan"] and cnode[:network][:networks]["nova_floating"]["use_vlan"]==cnode[:network][:networks]["public"]["use_vlan"] and cnode[:network][:networks]["nova_floating"]["add_bridge"]==cnode[:network][:networks]["public"]["add_bridge"]
          net_svc.allocate_ip "default", "public", "host", n
        else
          net_svc.enable_interface "default", "nova_floating", n
          net_svc.allocate_ip "default", "public", "host", n
        end
        #unless role.default_attributes["nova"]["network"]["tenant_vlans"] # or role.default_attributes["nova"]["networking_backend"]=="quantum"
        #net_svc.allocate_ip "default", "nova_fixed", "router", n
        #end
      end
    end

      #all_nodes.each do |n|
      #  net_svc.enable_interface "default", "nova_fixed", n
      #end

    @logger.debug("Quantum apply_role_pre_chef_call: leaving")
  end


end

