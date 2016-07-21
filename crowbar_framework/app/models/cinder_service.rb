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

class CinderService < PacemakerServiceObject
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
          "cluster" => true,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
        },
        "cinder-volume" => {
          "unique" => false,
          "count" => -1,
          "cluster" => true,
          "admin" => false,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    ["database", "keystone", "glance", "rabbitmq"].each do |dep|
      answer << { "barclamp" => dep, "inst" => role.default_attributes[@bc_name]["#{dep}_instance"] }
    end
    answer
  end

  def create_proposal
    @logger.debug("Cinder create_proposal: entering")
    base = super

    nodes = NodeObject.all
    controllers = select_nodes_for_role(nodes, "cinder-controller", "controller") || []
    storage = select_nodes_for_role(nodes, "cinder-volume", "storage") || []

    base["deployment"][@bc_name]["elements"] = {
      "cinder-controller" => controllers.empty? ? [] : [controllers.first.name],
      "cinder-volume" => storage.map { |x| x.name }
    }

    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Cinder create_proposal: exiting")
    base
  end

  def validate_proposal_after_save proposal
    validate_one_for_role proposal, "cinder-controller"
    validate_at_least_n_for_role proposal, "cinder-volume", 1

    volume_names = {}
    local_file_names = {}
    local_count = 0
    raw_count = 0
    raw_want_all = false
    rbd_crowbar = false
    rbd_ceph_conf = false

    proposal["attributes"][@bc_name]["volumes"].each do |volume|
      backend_driver = volume["backend_driver"]

      if volume[backend_driver].nil?
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_proposal",
          backend_driver: backend_driver
        )
        next
      end

      if backend_driver == "local"
        volume_name = volume["local"]["volume_name"]
        volume_names[volume_name] = (volume_names[volume_name] || 0) + 1

        file_name = volume["local"]["file_name"]
        local_file_names[file_name] = (local_file_names[file_name] || 0) + 1

        local_count += 1
      end

      if backend_driver == "raw"
        volume_name = volume["raw"]["volume_name"]
        volume_names[volume_name] = (volume_names[volume_name] || 0) + 1

        raw_count += 1
        raw_want_all = (volume["raw"]["cinder_raw_method"] != "first")
      end

      if backend_driver == "rbd"
        rbd_crowbar ||= volume["rbd"]["use_crowbar"]
        rbd_ceph_conf ||= !volume["rbd"]["use_crowbar"] && (volume["rbd"]["config_file"].strip == "/etc/ceph/ceph.conf")
      end
    end

    volume_names.each do |volume_name, count|
      if count > 1
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.volume_name",
          count: count, volume_name: volume_name
        )
      end
    end

    local_file_names.each do |file_name, count|
      if file_name.empty?
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.empty_filename",
          file_name: file_name
        )
      elsif file_name[0,1] != "/"
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_filename",
          file_name: file_name
        )
      end

      if file_name =~ /\s/
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_whitespaces_in_filename",
          file_name: file_name
        )
      end

      if count > 1
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_backend_filename",
          count: count, file_name: file_name
        )
      end
    end

    volume_elements = proposal["deployment"][@bc_name]["elements"]["cinder-volume"]
    volume_clusters = volume_elements.select { |n| is_cluster? n }

    if (local_count > 0 || raw_count > 0) && volume_clusters.any?
      validation_error I18n.t("barclamp.#{@bc_name}.validation.lvm_ha")
    elsif raw_count > 0
        if raw_count > 1 && raw_want_all
          validation_error I18n.t("barclamp.#{@bc_name}.validation.raw_device_backend")
        else
          nodes_without_suitable_drives = volume_elements.select do |node_name|
            node = NodeObject.find_node_by_name(node_name)
            if node.nil?
              false
            else
              candidate_disks_count = node.unclaimed_physical_drives.length + node.physical_drives.select { |d, data| node.disk_owner(node.unique_device_for(d)) == "Cinder" }.length
              candidate_disks_count < raw_count
            end
          end
          unless nodes_without_suitable_drives.empty?
            validation_error I18n.t(
              "barclamp.#{@bc_name}.validation.missing_unclaimed_disk",
              nodes_without_suitable_drives: nodes_without_suitable_drives.to_sentence
            )
          end
        end
    end

    if rbd_crowbar && rbd_ceph_conf
      validation_error I18n.t("barclamp.#{@bc_name}.validation.rados_backends")
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Cinder apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    controller_elements, controller_nodes, ha_enabled = role_expand_elements(role, "cinder-controller")
    reset_sync_marks_on_clusters_founders(controller_elements)
    Openstack::HA.set_controller_role(controller_nodes) if ha_enabled

    volume_elements = role.override_attributes[@bc_name]["elements"]["cinder-volume"] || []
    volume_ha_elements = volume_elements.select { |e| PacemakerServiceObject.is_cluster? e }
    unless volume_ha_elements.empty?
      reset_sync_marks_on_clusters_founders(volume_ha_elements)
      volume_ha_nodes = volume_ha_elements.map { |e| PacemakerServiceObject.expand_nodes(e) }
      volume_ha_nodes.flatten!
      Openstack::HA.set_controller_role(volume_ha_nodes)
    end

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["cinder", "ha", "enabled"], ha_enabled, controller_elements, vip_networks)
    role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    controller_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    # No specific need to call sync dns here, as the cookbook doesn't require
    # the VIP of the cluster to be setup
    allocate_virtual_ips_for_any_cluster_in_networks(controller_elements, vip_networks)

    # Generate secrets uuid for libvirt rbd backend
    dirty = false
    proposal = Proposal.find_by(barclamp: "cinder", name: role.inst)
    role.default_attributes[:cinder][:volumes].each_with_index do |volume, volid|
      next unless volume[:backend_driver] == "rbd"
      if volume[:rbd][:secret_uuid].empty?
        secret_uuid = `uuidgen`.strip
        volume[:rbd][:secret_uuid] = secret_uuid
        proposal[:attributes][:cinder][:volumes][volid][:rbd][:secret_uuid] = secret_uuid
        dirty = true
      end
    end
    if dirty
      # This makes the proposal in the UI looked as 'applied', even if you make changes to it
      proposal.save(applied: true)
      role.save
    end

    @logger.debug("Cinder apply_role_pre_chef_call: leaving")
  end
end

