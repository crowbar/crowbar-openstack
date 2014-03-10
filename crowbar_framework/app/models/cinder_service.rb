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
    super(thelogger)
    @bc_name = "cinder"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "cinder-controller" => {
          "unique" => false,
          "count" => 1,
          "admin" => false
        },
        "cinder-volume" => {
          "unique" => false,
          "count" => -1,
          "admin" => false
        }
      }
    end
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
      controller        = nodes.detect { |n| n.intended_role == "controller"} || nodes.first
      storage           = nodes.detect { |n| n.intended_role == "storage" } || controller
      base["deployment"]["cinder"]["elements"] = {
        "cinder-controller"     => [ controller[:fqdn] ],
        "cinder-volume"         => [ storage[:fqdn] ]
      }
    end

    base["attributes"][@bc_name]["git_instance"] = find_dep_proposal("git", true)
    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")

    base["attributes"]["cinder"]["service_password"] = '%012d' % rand(1e12)

    @logger.debug("Cinder create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "cinder-controller"
    validate_at_least_n_for_role proposal, "cinder-volume", 1

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    super
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

