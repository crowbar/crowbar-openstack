#
# Copyright 2017, SUSE LINUX GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class OscmService < PacemakerServiceObject
  def initialize(thelogger)
    @bc_name = "oscm"
    @logger = thelogger
  end

  class << self
    # Turn off multi proposal support till it really works and people ask for it.
    def self.allow_multiple_proposals?
      false
    end

    def role_constraints
      {
        "oscm-server" => {
          "unique" => false,
          "count" => 1,
          "admin" => false,
          "cluster" => false,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
        },
      }
    end
  end

  
  def proposal_dependencies(role)
    answer = []
    ["heat"].each do |dep|
      answer << { "barclamp" => dep, "inst" => role.default_attributes[@bc_name]["#{dep}_instance"] }
    end
    answer
  end

  def create_proposal
    @logger.debug("Oscm create_proposal: entering")
    base = super

    nodes = NodeObject.all
    server_nodes = nodes.select { |n| n.intended_role == "controller" }
    server_nodes = [nodes.first] if server_nodes.empty?

    base["deployment"][@bc_name]["elements"] = {
      "oscm-server" => [server_nodes.first.name]
    } unless server_nodes.nil?
    
    base["attributes"][@bc_name]["heat_instance"] = find_dep_proposal("heat")

    @logger.debug("Oscm create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "oscm-server"

    super
  end

end
