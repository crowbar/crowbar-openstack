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

class CeilometerService < ServiceObject

  def initialize(thelogger)
    @bc_name = "ceilometer"
    @logger = thelogger
  end

  def self.allow_multiple_proposals?
    true
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["ceilometer"]["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["ceilometer"]["keystone_instance"] }
    if role.default_attributes["ceilometer"]["use_gitrepo"]
      answer << { "barclamp" => "git", "inst" => role.default_attributes["ceilometer"]["git_instance"] }
    end
    answer
  end

  def create_proposal
    base = super

    agent_nodes = NodeObject.find("roles:nova-multi-compute")

    server_nodes = NodeObject.find("roles:nova-multi-controller")
        
    base["attributes"][@bc_name]["git_instance"] = ""
    begin
      gitService = GitService.new(@logger)
      gits = gitService.list_active[1]
      if gits.empty?
        # No actives, look for proposals
        gits = gitService.proposals[1]
      end
      unless gits.empty?
        base["attributes"]["ceilometer"]["git_instance"] = gits[0]
      end
    rescue
      @logger.info("#{@bc_name} create_proposal: no git found")
    end

    base["attributes"]["ceilometer"]["keystone_instance"] = ""
    begin
      keystoneService = KeystoneService.new(@logger)
      keystones = keystoneService.list_active[1]
      if keystones.empty?
        # No actives, look for proposals
        keystones = keystoneService.proposals[1]
      end
      if !keystones.empty?
        base["attributes"]["ceilometer"]["keystone_instance"] = keystones[0]
      end
    rescue
      @logger.info("ceilometer create_proposal: no keystone found")
    end


    base["attributes"][@bc_name]["rabbitmq_instance"] = ""
    begin
      rabbitmqService = RabbitmqService.new(@logger)
      rabbits = rabbitmqService.list_active[1]
      if rabbits.empty?
        # No actives, look for proposals
        rabbits = rabbitmqService.proposals[1]
      end
      unless rabbits.empty?
        base["attributes"]["ceilometer"]["rabbitmq_instance"] = rabbits[0]
      end
    rescue
      @logger.info("#{@bc_name} create_proposal: no rabbitmq found")
    end

    base["deployment"]["ceilometer"]["elements"] = {
        "ceilometer-agent" =>  agent_nodes.map { |x| x.name },
        "ceilometer-cagent" =>  server_nodes.map { |x| x.name },
        "ceilometer-server" =>  server_nodes.map { |x| x.name }
    } unless agent_nodes.nil? or server_nodes.nil?

    #base[:attributes][:ceilometer][:service][:token] = '%012d' % rand(1e12)
    #base["attributes"]["ceilometer"]["service_password"] = '%012d' % rand(1e12)

    base
  end
end

