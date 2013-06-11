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

class RabbitmqService < ServiceObject

  def initialize(thelogger)
    @bc_name = "rabbitmq"
    @logger = thelogger
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  def proposal_dependencies(role)
    answer = []
    answer
  end

  def create_proposal
    @logger.debug("Rabbitmq create_proposal: entering")
    base = super
    @logger.debug("Rabbitmq create_proposal: done with base")

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? }
    nodes.delete_if { |n| n.admin? } if nodes.size > 1
    head = nodes.shift
    base["deployment"]["rabbitmq"]["elements"] = {
      "rabbitmq-server" => [ head.name ]
    }

    @logger.debug("Rabbitmq create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Rabbitmq apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    om = old_role ? old_role.default_attributes["rabbitmq"] : {}
    nm = role.default_attributes["rabbitmq"]
    if om["password"]
      nm["password"] = om["password"]
    else
      nm["password"] = random_password
    end
    role.save

    @logger.debug("Rabbitmq apply_role_pre_chef_call: leaving")
  end

end

