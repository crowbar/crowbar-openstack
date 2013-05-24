# Copyright 2012, Dell Inc. 
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

class CinderService < ServiceObject

  def initialize(thelogger)
    @bc_name = "cinder"
    @logger = thelogger
  end

  #if barclamp allows multiple proposals OVERRIDE
  # def self.allow_multiple_proposals?

  def proposal_dependencies(role)
    answer = []
    deps = ["database", "keystone", "glance", "rabbitmq"]
    deps << "git" if role.default_attributes[@bc_name]["use_gitrepo"]
    deps.each do |dep|
      answer << { "barclamp" => dep, "inst" => role.default_attributes[@bc_name]["#{dep}_instance"] }
    end
    answer
  end

  def create_proposal
    @logger.debug("Cinder create_proposal: entering")
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    if nodes.size >= 1
      base["deployment"]["cinder"]["elements"] = {
        "cinder-server" => [ nodes.first[:fqdn] ]
      }
    end

    insts = ["Database", "Keystone", "Glance", "Rabbitmq"]
    insts << "Git" if base["attributes"][@bc_name]["use_gitrepo"]

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

    base["attributes"]["cinder"]["service_password"] = '%012d' % rand(1e12)
    base["attributes"]["cinder"]["db"]["password"] = random_password

    @logger.debug("Cinder create_proposal: exiting")
    base
  end

end

