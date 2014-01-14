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
    super(thelogger)
    @bc_name = "ceilometer"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["ceilometer"]["rabbitmq_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["ceilometer"]["keystone_instance"] }
    unless role.default_attributes["ceilometer"]["use_mongodb"]
      answer << { "barclamp" => "database", "inst" => role.default_attributes["ceilometer"]["database_instance"] }
    end
    if role.default_attributes["ceilometer"]["use_gitrepo"]
      answer << { "barclamp" => "git", "inst" => role.default_attributes["ceilometer"]["git_instance"] }
    end
    answer
  end

  def create_proposal
    @logger.debug("Ceilometer create_proposal: entering")
    base = super

    base["attributes"][@bc_name]["git_instance"] = find_dep_proposal("git", true)
    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database", true)
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    agent_nodes = NodeObject.find("roles:nova-multi-compute-kvm") +
      NodeObject.find("roles:nova-multi-compute-qemu") +
      NodeObject.find("roles:nova-multi-compute-vmware") +
      NodeObject.find("roles:nova-multi-compute-xen")

    nodes       = NodeObject.all
    server_nodes = nodes.select { |n| n.intended_role == "controller" }
    server_nodes = [ nodes.first ] if server_nodes.empty?

    base["deployment"]["ceilometer"]["elements"] = {
        "ceilometer-agent" =>  agent_nodes.map { |x| x.name },
        "ceilometer-cagent" =>  server_nodes.map { |x| x.name },
        "ceilometer-server" =>  server_nodes.map { |x| x.name }
    } unless agent_nodes.nil? or server_nodes.nil?

    base["attributes"]["ceilometer"]["keystone_service_password"] = '%012d' % rand(1e12)

    @logger.debug("Ceilometer create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "ceilometer-cagent"
    validate_one_for_role proposal, "ceilometer-server"

    if proposal["attributes"][@bc_name]["use_gitrepo"]
      validate_dep_proposal_is_active "git", proposal["attributes"][@bc_name]["git_instance"]
    end

    super
  end


  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Ceilometer apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    net_svc = NetworkService.new @logger
    tnodes = role.override_attributes["ceilometer"]["elements"]["ceilometer-server"]
    tnodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end unless tnodes.nil?

    @logger.debug("Ceilometer apply_role_pre_chef_call: leaving")
  end

end
