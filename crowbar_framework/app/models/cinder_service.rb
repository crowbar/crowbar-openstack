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

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end


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
        "cinder-controller" => [ nodes.first[:fqdn] ],
        "cinder-volume" => [ nodes.first[:fqdn] ]
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

    if base["attributes"][@bc_name]["database_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "database"))
    end

    if base["attributes"][@bc_name]["keystone_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "keystone"))
    end

    if base["attributes"][@bc_name]["glance_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "glance"))
    end

    if base["attributes"][@bc_name]["rabbitmq_instance"] == ""
      raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "rabbitmq"))
    end

    base["attributes"]["cinder"]["service_password"] = '%012d' % rand(1e12)

    @logger.debug("Cinder create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    super
    if proposal["attributes"][@bc_name]["use_gitrepo"]
      gitService = GitService.new(@logger)
      gits = gitService.list_active[1]
      if gits.empty?
        # No actives, look for proposals
        gits = gitService.proposals[1]
      end
      if not gits.include?proposal["attributes"][@bc_name]["git_instance"]
        raise(I18n.t('model.service.dependency_missing', :name => @bc_name, :dependson => "git"))
      end
    end
  end


  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Cinder apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    net_svc = NetworkService.new @logger
    tnodes = role.override_attributes["cinder"]["elements"]["cinder-controller"]
    tnodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end unless tnodes.nil?

    @logger.debug("Cinder apply_role_pre_chef_call: leaving")
  end

end

