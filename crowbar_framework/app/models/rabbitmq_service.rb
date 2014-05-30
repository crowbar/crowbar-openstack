#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
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

class RabbitmqService < PacemakerServiceObject

  def initialize(thelogger)
    super(thelogger)
    @bc_name = "rabbitmq"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "rabbitmq-server" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true
        }
      }
    end
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
    controller = nodes.find { |n| n if n.intended_role == "controller" } || nodes.first
    base["deployment"]["rabbitmq"]["elements"] = {
      "rabbitmq-server" => [ controller.name ]
    }

    base["attributes"][@bc_name]["password"] = random_password

    @logger.debug("Rabbitmq create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Rabbitmq apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    rabbitmq_elements, rabbitmq_nodes, rabbitmq_ha_enabled = role_expand_elements(role, "rabbitmq-server")
    role.save if prepare_role_for_ha(role, ["rabbitmq", "ha", "enabled"], rabbitmq_ha_enabled)

    if rabbitmq_ha_enabled
      net_svc = NetworkService.new @logger
      unless rabbitmq_elements.length == 1 && PacemakerServiceObject.is_cluster?(rabbitmq_elements[0])
        raise "Internal error: HA enabled, but element is not a cluster"
      end
      cluster = rabbitmq_elements[0]
      rabbitmq_vhostname = "#{role.name.gsub("-config", "")}-#{PacemakerServiceObject.cluster_name(cluster)}.#{ChefObject.cloud_domain}".gsub("_", "-")
      net_svc.allocate_virtual_ip "default", "admin", "host", rabbitmq_vhostname
      # rabbitmq, on start, needs to have the virtual hostname resolvable; so
      # let's force a dns update now
      ensure_dns_uptodate
    end

    @logger.debug("Rabbitmq apply_role_pre_chef_call: leaving")
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "rabbitmq-server"

    attributes = proposal["attributes"][@bc_name]

    # HA validation
    servers = proposal["deployment"][@bc_name]["elements"]["rabbitmq-server"]
    unless servers.nil? || servers.first.nil? || !is_cluster?(servers.first)
      storage_mode = attributes["ha"]["storage"]["mode"]
      validation_error("Unknown mode for HA storage: #{storage_mode}.") unless %w(shared drbd).include?(storage_mode)

      if storage_mode == "shared"
        validation_error("No device specified for shared storage.") if attributes["ha"]["storage"]["shared"]["device"].blank?
        validation_error("No filesystem type specified for shared storage.") if attributes["ha"]["storage"]["shared"]["fstype"].blank?
      elsif storage_mode == "drbd"
        cluster = servers.first
        role = available_clusters[cluster]
        validation_error("DRBD is not enabled for cluster #{cluster_name(cluster)}.") unless role.default_attributes["pacemaker"]["drbd"]["enabled"]
        validation_error("Invalid size for DRBD device.") if attributes["ha"]["storage"]["drbd"]["size"] <= 0
      end
    end

    super
  end
end

