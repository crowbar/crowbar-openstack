#
# Copyright 2015, SUSE LINUX GmbH
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

class ManilaService < OpenstackServiceObject
  def initialize(thelogger = nil)
    @bc_name = "manila"
    @logger = thelogger
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "manila-server" => {
          "unique" => false,
          "count" => 1,
          "cluster" => true,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        },
        "manila-share" => {
          "unique" => false,
          "count" => -1,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    # NOTE(toabctl): nova, cinder, glance and neutron are just needed
    # for the generic driver. So this could be optional depending on the used
    # driver
    deps = ["database", "rabbitmq", "keystone", "nova", "cinder", "glance", "neutron"]
    deps.each do |dep|
      answer << {
        "barclamp" => dep,
        "inst" => role.default_attributes[@bc_name]["#{dep}_instance"]
      }
    end
    answer
  end

  def create_proposal
    @logger.debug("Manila create_proposal: entering")
    base = super

    nodes = NodeObject.all
    controllers = select_nodes_for_role(
      nodes, "manila-server", "controller") || []
    # NOTE(toabctl): Use storage nodes for the share service, but that
    # could be any other node, too
    storage = select_nodes_for_role(
      nodes, "manila-share", "storage") || []

    # Do not put manila-share roles to compute nodes
    # (it does not work with non-disruptive upgrade)
    shares = storage.reject { |n| n.roles.include? "nova-compute-kvm" }

    # Take at least one manila-share role if it was emptied by previous filter
    shares << controllers.first if shares.empty?

    base["deployment"][@bc_name]["elements"] = {
      "manila-server" => controllers.empty? ?
    [] : [controllers.first.name],
      "manila-share" => shares.map(&:name)
    }

    base["attributes"][@bc_name]["database_instance"] =
      find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] =
      find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] =
      find_dep_proposal("keystone")
    base["attributes"][@bc_name]["nova_instance"] =
      find_dep_proposal("nova")
    base["attributes"][@bc_name]["cinder_instance"] =
      find_dep_proposal("cinder")
    base["attributes"][@bc_name]["glance_instance"] =
      find_dep_proposal("glance")
    base["attributes"][@bc_name]["neutron_instance"] =
      find_dep_proposal("neutron")

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name]["memcache_secret_key"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Manila create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "manila-server"
    validate_at_least_n_for_role proposal, "manila-share", 1

    proposal["attributes"][@bc_name]["shares"].each do |share|
      backend_driver = share["backend_driver"]

      # validate generic driver
      if backend_driver == "generic"
        # mandatory parameters
        if share[backend_driver]["service_instance_user"].empty?
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.generic.service_instance_user")
        end
        if share[backend_driver]["service_instance_name_or_id"].empty?
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.generic.service_instance_name_or_id")
        end
        if share[backend_driver]["service_net_name_or_ip"].empty?
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.generic.service_net_name_or_ip")
        end
        if share[backend_driver]["tenant_net_name_or_ip"].empty?
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.generic.tenant_net_name_or_ip")
        end
        # there must be a private ssh key path or a password
        unless ["service_instance_password", "path_to_private_key"].any? do |s|
          !share[backend_driver][s].empty?
        end
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.generic.password_or_private_key")
        end
      end

      # validate cephfs driver
      if backend_driver == "cephfs"
        # check that Ceph with an MDS role is deployed
        if share["cephfs"]["use_crowbar"]
          ceph_mds_nodes = NodeObject.find("roles:ceph-mds")
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.cephfs.ceph_mds_not_deployed"
          ) if ceph_mds_nodes.empty?
        end
      end
    end
    super
  end

  def apply_role_pre_chef_call(_old_role, role, all_nodes)
    @logger.debug("Manila apply_role_pre_chef_call: "\
                  "entering #{all_nodes.inspect}")

    return if all_nodes.empty?

    controller_elements,
    controller_nodes,
    ha_enabled = role_expand_elements(role, "manila-server")
    reset_sync_marks_on_clusters_founders(controller_elements)
    Openstack::HA.set_controller_role(controller_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    dirty = prepare_role_for_ha_with_haproxy(
      role, ["manila", "ha", "enabled"],
      ha_enabled, controller_elements, vip_networks)
    role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    controller_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    # No specific need to call sync dns here, as the cookbook doesn't require
    # the VIP of the cluster to be setup
    allocate_virtual_ips_for_any_cluster_in_networks(
      controller_elements, vip_networks)

    # Make sure the bind hosts are in the admin network
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n

      admin_address = node.get_network_by_type("admin")["address"]
      node.crowbar[:manila] = {} if node.crowbar[:manila].nil?
      node.crowbar[:manila][:api_bind_host] = admin_address

      node.save
    end

    # manila-share service needs a extra section in ceph.conf
    ceph_conf_extra_section = %q(
client mount uid = 0
client mount gid = 0
log file = /var/log/manila/ceph-client.manila.log
admin socket = /var/run/manila/ceph-$name.$pid.asok
keyring = /etc/ceph/ceph.client.manila.keyring
)

    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n
      node["ceph"] ||= {}
      node["ceph"]["config_sections"] ||= {}
      node["ceph"]["config_sections"]["client.manila"] = ceph_conf_extra_section
      node.save
    end

    @logger.debug("Manila apply_role_pre_chef_call: leaving")
  end
end
