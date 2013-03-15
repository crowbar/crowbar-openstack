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
    if role.default_attributes["ceilometer"]["sql_engine"] == "mysql"
      answer << { "barclamp" => "mysql", "inst" => role.default_attributes["ceilometer"]["mysql_instance"] }
    end
    if role.default_attributes["ceilometer"]["use_gitrepo"]
      answer << { "barclamp" => "git", "inst" => role.default_attributes["ceilometer"]["git_instance"] }
    end
    answer
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }
    
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


    base["attributes"]["ceilometer"]["mysql_instance"] = ""
    begin
      mysqlService = MysqlService.new(@logger)
      # Look for active roles
      mysqls = mysqlService.list_active[1]
      if mysqls.empty?
        # No actives, look for proposals
        mysqls = mysqlService.proposals[1]
      end
      if mysqls.empty?
        base["attributes"]["ceilometer"]["sql_engine"] = "sqlite"
      else
        base["attributes"]["ceilometer"]["mysql_instance"] = mysqls[0]
        base["attributes"]["ceilometer"]["sql_engine"] = "mysql"
      end
    rescue
      @logger.info("Ceilometercreate_proposal: no mysql found")
      base["attributes"]["ceilometer"]["sql_engine"] = "sqlite"
    end
    
    base["deployment"]["ceilometer"]["elements"] = {
        "ceilometer-agent" =>  agent_nodes.map { |x| x.name },
        "ceilometer-cagent" =>  server_nodes.map { |x| x.name },
        "ceilometer-server" =>  server_nodes.map { |x| x.name }
    } unless nodes.nil? or nodes.length ==0

    base[:attributes][:ceilometer][:service][:token] = '%012d' % rand(1e12)
    base["attributes"]["ceilometer"]["service_password"] = '%012d' % rand(1e12)


    base
  end
end

