# Copyright 2013, Mirantis 
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

class InteltxtService < ServiceObject

  def initialize(thelogger)
    @bc_name = "inteltxt"
    @logger = thelogger
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "database", "inst" => role.default_attributes["inteltxt"]["database_instance"] }
    answer
  end
  
  #if barclamp allows multiple proposals OVERRIDE
  # def self.allow_multiple_proposals?
  
  def create_proposal
    @logger.debug("Inteltxt create_proposal: entering")
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    if nodes.size >= 1
      base["deployment"]["inteltxt"]["elements"] = {
        "oat-server" => [ nodes.first[:fqdn] ]
      }
    end

    base["attributes"]["inteltxt"]["database_instance"] = ""
    begin
      databaseService = DatabaseService.new(@logger)
      # Look for active roles
      databases = databaseService.list_active[1]
      if databases.empty?
        # No actives, look for proposals
        databases = databaseService.proposals[1]
      end
      base["attributes"]["inteltxt"]["database_instance"] = databases[0] unless databases.empty?
    rescue
      @logger.info("Inteltxt create_proposal: no databases found")
    end
    

    @logger.debug("Inteltxt create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Inteltxt apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    om = old_role ? old_role.default_attributes["inteltxt"] : {}
    nm = role.default_attributes["inteltxt"]
    begin
      if om["db"]["password"]
        nm["db"]["password"] = om["db"]["password"]
      else
        nm["db"]["password"] = random_password
      end
    rescue
      nm["db"]["password"] = random_password
    end
    role.save 
    @logger.debug("Inteltxt apply_role_pre_chef_call: leaving")
  end

end

