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

class NovaService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "nova"
  end

# Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "nova-controller" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "nova-compute-hyperv" => {
          "unique" => false,
          "count" => -1,
          "platform" => {
            "windows" => "/.*/"
          }
        },
        "nova-compute-kvm" => {
          "unique" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "remotes" => true
        },
        "nova-compute-qemu" => {
          "unique" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "remotes" => true
        },
        "nova-compute-vmware" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        },
        "nova-compute-zvm" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          }
        },
        "nova-compute-xen" => {
          "unique" => false,
          "count" => -1,
          "platform" => {
            "suse" => ">= 12.4"
          },
          "remotes" => true
        },
        "nova-compute-ironic" => {
          "unique" => false,
          "count" => 1,
          "platform" => {
            "suse" => ">= 12.4"
          },
          "remotes" => false
        },
        "ec2-api" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "database", "inst" => role.default_attributes["nova"]["database_instance"] }
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["nova"]["keystone_instance"] }
    answer << { "barclamp" => "glance", "inst" => role.default_attributes["nova"]["glance_instance"] }
    answer << { "barclamp" => "rabbitmq", "inst" => role.default_attributes["nova"]["rabbitmq_instance"] }
    answer << { "barclamp" => "cinder", "inst" => role.default_attributes[@bc_name]["cinder_instance"] }
    answer << { "barclamp" => "neutron", "inst" => role.default_attributes[@bc_name]["neutron_instance"] }
    answer
  end

  def node_supports_xen(node)
    return false if node[:platform_family] != "suse"
    return false if node[:block_device].include?("vda")
    node["kernel"]["machine"] =~ /x86_64/
  end

  def node_supports_kvm(node)
    return false if node[:cpu].nil? || node[:cpu]["0"].nil? || node[:cpu]["0"][:flags].nil?
    return true if node["kernel"]["machine"] =~ /(aarch64|s390x)/
    node[:cpu]["0"][:flags].include?("vmx") or node[:cpu]["0"][:flags].include?("svm")
  end

  #
  # Lots of enhancements here.  Like:
  #    * Don't reuse machines
  #    * validate hardware.
  #
  def create_proposal
    @logger.debug("Nova create_proposal: entering")
    base = super
    @logger.debug("Nova create_proposal: done with base")

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? }
    nodes.delete_if { |n| n.admin? } if nodes.size > 1
    nodes.delete_if { |n| n.intended_role == "storage" }

    controller  = nodes.delete nodes.detect { |n| n if n.intended_role == "controller" }
    controller ||= nodes.shift
    nodes = [controller] if nodes.empty?

    # Defaults for AArch64: disable VNC, enable Serial
    base["attributes"]["nova"]["use_serial"] = controller[:kernel][:machine] == "aarch64"
    base["attributes"]["nova"]["use_novnc"] = controller[:kernel][:machine] != "aarch64"

    # restrict nodes to 'compute' roles only if compute role was defined
    if nodes.detect { |n| n if n.intended_role == "compute" }
      nodes       = nodes.select { |n| n if n.intended_role == "compute" }
    end

    hyperv = nodes.select { |n| n if n[:target_platform] =~ /^(windows-|hyperv-)/ }
    non_hyperv = nodes - hyperv
    kvm = non_hyperv.select { |n| n if node_supports_kvm(n) }
    non_kvm = non_hyperv - kvm
    xen = non_kvm.select { |n| n if node_supports_xen(n) }
    qemu = non_kvm - xen

    # do not use zvm by default
    #   TODO add it here once a compute node can run inside z/VM
    # (2017-01-30) Hyper-V is hidden for now
    # "nova-compute-hyperv" => hyperv.map(&:name),
    base["deployment"]["nova"]["elements"] = {
      "nova-controller" => [controller.name],
      "nova-compute-kvm" => kvm.map(&:name),
      "nova-compute-qemu" => qemu.map(&:name),
      "nova-compute-xen" => xen.map(&:name)
    }

    base["attributes"][@bc_name]["itxt_instance"] = find_dep_proposal("itxt", true)
    base["attributes"][@bc_name]["database_instance"] = find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] = find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")
    base["attributes"][@bc_name]["cinder_instance"] = find_dep_proposal("cinder")
    base["attributes"][@bc_name]["neutron_instance"] = find_dep_proposal("neutron")

    base["attributes"]["nova"]["service_password"] = random_password
    base["attributes"]["nova"]["placement_service_password"] = random_password
    base["attributes"]["nova"]["memcache_secret_key"] = random_password
    base["attributes"]["nova"]["api_db"]["password"] = random_password
    base["attributes"]["nova"]["placement_db"]["password"] = random_password
    base["attributes"]["nova"]["db"]["password"] = random_password
    base["attributes"]["nova"]["neutron_metadata_proxy_shared_secret"] = random_password

    base["attributes"]["nova"]["ec2-api"]["db"]["password"] = random_password
    base["attributes"]["nova"]["compute_remotefs_sshkey"] = %x[
      t=$(mktemp)
      rm -f $t
      ssh-keygen -q -t ed25519 -N "" -f $t
      cat $t
      rm -f $t ${t}.pub
    ]

    @logger.debug("Nova create_proposal: exiting")
    base
  end

  # Override this so we can change elements and element_order dynamically on
  # apply:
  #  - when there are compute roles using clusters with remote nodes, we need
  #    to have some role on the corosync nodes of the clusters, running after
  #    the compute roles (this will be nova-ha-compute)
  #  - when that is not the case, we of course do not need that. We still keep
  #    the element_order addition in order to deal with clusters that are
  #    removed (because apply_role looks at element_order to decide what role
  #    to look at)
  # Note that we do not put nova-ha-compute in element_order in the proposal to
  # keep it hidden from the user: this is something that should never be
  # changed by the user, as it's handled automatically.
  def active_update(proposal, inst, in_queue, bootstrap = false)
    deployment = proposal["deployment"]["nova"]
    elements = deployment["elements"]

    # always reset elements of nova-ha-compute in case the user tried to
    # provide that in the proposal
    unless elements.fetch("nova-ha-compute", []).empty?
      @logger.warn("nova: discarding nova-ha-compute elements from proposal; " \
        "this role is automatically filled")
    end
    elements["nova-ha-compute"] = []
    # always include nova-ha-compute in the batches for apply_role (see long
    # comment above)
    unless deployment["element_order"].flatten.include?("nova-ha-compute")
      deployment["element_order"].push(["nova-ha-compute"])
    end

    # find list of roles which accept clusters with remote nodes
    roles_with_remote = role_constraints.select do |role, constraints|
      constraints["remotes"]
    end.keys

    # now examine all elements in these roles, and look for clusters
    roles_with_remote.each do |role|
      next unless elements.key? role
      elements[role].each do |element|
        next unless is_remotes? element

        cluster = PacemakerServiceObject.cluster_from_remotes(element)
        @logger.debug("nova: Ensuring that #{cluster} has nova-ha-compute role")
        elements["nova-ha-compute"].push(cluster)
      end
    end

    # no need to save proposal, it's just data that is passed to later methods
    super
  end

  def set_ha_compute(node, enabled)
    n = NodeObject.find_node_by_name(node)
    n[:nova] ||= {}
    n[:nova][:ha] ||= {}
    n[:nova][:ha][:compute] ||= {}
    if n[:nova][:ha][:compute][:enabled] != enabled
      n[:nova][:ha][:compute][:enabled] = enabled
      n.save
    end
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Nova apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    unless hyperv_available?
      role.override_attributes["nova"]["elements"]["nova-compute-hyperv"] = []
    end

    controller_elements, controller_nodes, ha_enabled = role_expand_elements(role, "nova-controller")
    # Only reset sync marks if we are really applying on all controller nodes;
    # if we are not, then we clearly do not intend to have some sync between
    # them during the chef run
    if Set.new(controller_nodes & all_nodes) == Set.new(controller_nodes)
      reset_sync_marks_on_clusters_founders(controller_elements)
    end
    Openstack::HA.set_controller_role(controller_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    #required for sync-mark mechanism
    role.default_attributes["ec2-api"] ||= {}
    role.default_attributes["ec2-api"]["crowbar-revision"] =
      role.override_attributes["nova"]["crowbar-revision"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["nova", "ha", "enabled"], ha_enabled, controller_elements, vip_networks)
    role.save if dirty

    ec2_controller_elements, ec2_controller_nodes, ec2_ha_enabled = role_expand_elements(role, "ec2-api")
    reset_sync_marks_on_clusters_founders(ec2_controller_elements)
    Openstack::HA.set_controller_role(ec2_controller_nodes) if ec2_ha_enabled

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["nova", "ec2-api", "ha", "enabled"], ec2_ha_enabled,  ec2_controller_elements, vip_networks)
    role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    controller_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(controller_elements, vip_networks)

    # enable ironic network interface, do this before enable_neutron_networks for proper bridge setup
    _, ironic_nodes, = role_expand_elements(role, "nova-compute-ironic")
    ironic_nodes.each do |n|
      net_svc.enable_interface "default", "ironic", n
    end

    neutron = Proposal.find_by(barclamp: "neutron",
                               name: role.default_attributes["nova"]["neutron_instance"])

    compute_nodes_for_network = []
    role.override_attributes["nova"]["elements"].each do |role_name, elements|
      # only care about compute nodes
      next unless role_name =~ /^nova-compute-/

      nodes = []

      elements.each do |element|
        if is_remotes? element
          remote_nodes = expand_remote_nodes(element)
          remote_nodes.each do |remote_node|
            set_ha_compute(remote_node, true)
          end
          nodes.concat(remote_nodes)

          cluster = PacemakerServiceObject.cluster_from_remotes(element)
          reset_sync_marks_on_clusters_founders([cluster])
          Openstack::HA.set_compute_role(remote_nodes)
        else
          set_ha_compute(element, false)
          nodes << element
        end
      end

      compute_nodes_for_network << nodes
    end
    compute_nodes_for_network.flatten!

    neutron_service = NeutronService.new @logger

    ceph_proposal = Proposal.find_by(barclamp: "ceph")
    network_proposal = Proposal.find_by(barclamp: "network")

    compute_nodes_for_network.each do |n|
      neutron_service.enable_neutron_networks(neutron["attributes"]["neutron"],
                                              n, net_svc,
                                              neutron["attributes"]["neutron"]["use_dvr"])
      if role.default_attributes["nova"]["use_migration"]
        net_svc.allocate_ip("default", role.default_attributes["nova"]["migration"]["network"],
                            "host", n)
      end

      # allocate a IP from the ceph_client network if Ceph is used
      if ceph_proposal
        ceph_client = ceph_proposal["attributes"]["ceph"]["client_network"]
        # is the ceph_client network really available?
        if network_proposal["attributes"]["network"]["networks"][ceph_client].nil?
          raise I18n.t(
            "barclamp.#{@bc_name}.validation.ceph_client_network_not_available",
            ceph_client: ceph_client
          )
        end
        @logger.info("Allocating an IP from the Ceph client network '#{ceph_client}' for node #{n}")
        net_svc.allocate_ip "default", ceph_client, "host", n
      end
    end unless all_nodes.nil?

    # Allocate IP for xcat_management network for z/VM nodes, if we're
    # configured to use something else than the "admin" network for it.
    zvm_compute_nodes = role.override_attributes["nova"]["elements"]["nova-compute-zvm"]
    unless zvm_compute_nodes.nil? || zvm_compute_nodes.empty?
      zvm_xcat_network = role.default_attributes["nova"]["zvm"]["zvm_xcat_network"]
      unless zvm_xcat_network == "admin"
        zvm_compute_nodes.each do |n|
          net_svc.allocate_ip("default", zvm_xcat_network, "host", n)
        end
      end
    end

    @logger.debug("Nova apply_role_pre_chef_call: leaving")
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "nova-controller"

    elements = proposal["deployment"]["nova"]["elements"]
    nodes = Hash.new(0)

    if proposal["attributes"][@bc_name]["setup_shared_instance_storage"]
      elements["nova-controller"].each do |element|
        if is_cluster? element
          validation_error I18n.t("barclamp.#{@bc_name}.validation.no_shared_storage_cluster")
          break
        end
      end unless elements["nova-controller"].nil?
      unless proposal["attributes"][@bc_name]["use_shared_instance_storage"]
        validation_error I18n.t("barclamp.#{@bc_name}.validation.setup_use_shared_storage")
      end
    end

    # unless elements["nova-compute-hyperv"].empty? || hyperv_available?
    #   validation_error I18n.t("barclamp.#{@bc_name}.validation.hyperv_support")
    # end

    unless elements["nova-compute-zvm"].nil? || elements["nova-compute-zvm"].empty?
      unless network_present? proposal["attributes"][@bc_name]["zvm"]["zvm_xcat_network"]
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_zvm_xcat_network",
          network: proposal["attributes"][@bc_name]["zvm"]["zvm_xcat_network"]
        )
      end
    end

    unless elements["nova-compute-ironic"].nil? || elements["nova-compute-ironic"].empty?
      unless network_present?("ironic")
        validation_error I18n.t("barclamp.#{@bc_name}.validation.ironic_network")
      end
      if Proposal.where(barclamp: "ironic").empty?
        validation_error I18n.t("barclamp.#{@bc_name}.validation.ironic_server")
      end
    end

    elements["nova-compute-kvm"].each do |n|
      nodes[n] += 1
    end unless elements["nova-compute-kvm"].nil?
    elements["nova-compute-qemu"].each do |n|
      nodes[n] += 1
    end unless elements["nova-compute-qemu"].nil?
    elements["nova-compute-vmware"].each do |n|
      nodes[n] += 1
    end unless elements["nova-compute-vmware"].nil?
    elements["nova-compute-zvm"].each do |n|
      nodes[n] += 1
    end unless elements["nova-compute-zvm"].nil?
    elements["nova-compute-xen"].each do |n|
      nodes[n] += 1

      node = NodeObject.find_node_by_name(n)
      next if node.nil? || node_supports_xen(node)

      node_platform = "#{node[:platform]}-#{node[:platform_version]}"
      validation_error I18n.t(
        "barclamp.#{@bc_name}.validation.xen",
        n: n,
        platform: Crowbar::Platform.pretty_target_platform(node_platform),
        arch: node["kernel"]["machine"]
      )
    end unless elements["nova-compute-xen"].nil?
    elements["nova-compute-ironic"].each do |n|
      nodes[n] += 1
    end unless elements["nova-compute-ironic"].nil?

    nodes.each do |key, value|
      if value > 1
        if is_remotes? key
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.assigned_remotes",
            key: cluster_name(key)
          )
        else
          validation_error I18n.t(
            "barclamp.#{@bc_name}.validation.assigned_node",
            key: key
          )
        end
      end
    end unless nodes.nil?

    all_elements = elements.values.flatten.compact
    remote_clusters = all_elements.select { |element| is_remotes? element }
    remote_clusters.each do |remote_cluster|
      remote_nodes = expand_remote_nodes(remote_cluster)
      remote_nodes.each do |remote_node|
        next unless all_elements.include? remote_node
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.assigned_node_and_remote",
          node: remote_node,
          cluster: cluster_name(remote_cluster)
        )
      end
    end

    if proposal["attributes"][@bc_name]["use_migration"]
      unless network_present? proposal["attributes"][@bc_name]["migration"]["network"]
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.invalid_migration_network",
          network: proposal["attributes"][@bc_name]["migration"]["network"]
        )
      end
    end

    # vendordata must be valid json
    begin
      JSON.parse(proposal["attributes"][@bc_name]["metadata"]["vendordata"]["json"])
    rescue JSON::ParserError
      validation_error I18n.t("barclamp.#{@bc_name}.validation.vendor_data_invalid_json")
    end

    super
  end

  # try to know if we can skip a node from running chef-client
  def skip_unchanged_node?(node, old_role, new_role)
    # if old_role is nil, then we are applying the barclamp for the first time, so no skip
    return false if old_role.nil?

    # if the node changed roles, then we need to apply, so no skip
    return false if node_changed_roles?(node, old_role, new_role)

    # if attributes have changed, we need to apply, so no skip
    return false if node_changed_attributes?(node, old_role, new_role)

    # if we use remote HA, let's be safe, so no skip
    return false if node_is_remote_ha?(node, new_role)

    # if the node is a controller, then we only need to apply if we move from
    # non-HA to HA (or vice-versa), since the config didn't change
    if node_is_nova_controller?(node, new_role)
      return false if node_changed_ha?(node, old_role, new_role)
    end

    # by this point its safe to assume that we can skip the node as nothing has changed on it
    # same attributes, same roles so skip it
    @logger.info("#{@bc_name} skip_batch_for_node? skipping: #{node}")
    true
  end

  private

  def node_changed_attributes?(node, old_role, new_role)
    old_role_attributes = old_role.default_attributes[@bc_name].deep_dup
    # we need to remove the HA keys from the old_role for nova/ec2-api,
    # as they get added afterwards to the new role during apply_role_pre_chef_call
    # so if we dont remove them, the comparision is always gonna fail
    old_role_attributes.delete("ha")
    old_role_attributes["ec2-api"].delete("ha")
    if old_role_attributes != new_role.default_attributes[@bc_name]
      logger.debug("Nova skip_batch_for_node?: not skipping #{node} (attribute change)")
      return true
    end

    false
  end

  def node_is_remote_ha?(node, new_role)
    new_role.override_attributes[@bc_name]["elements"].each do |role_name, elements|
      next unless role_name =~ /^nova-compute-/
      elements.each do |element|
        if is_remotes?(element)
          @logger.debug("Nova skip_batch_for_node?: not skipping #{node} (compute HA)")
          return true
        end
      end
    end

    false
  end

  def node_changed_ha?(node, old_role, new_role)
    old_elements = old_role.override_attributes[@bc_name]["elements"]
    new_elements = new_role.override_attributes[@bc_name]["elements"]

    if old_elements["nova-controller"] == new_elements["nova-controller"]
      @logger.debug("Nova skip_batch_for_node?: skipping #{node} (no controller change)")
      return false
    end

    true
  end

  # find out if this node is a controller
  def node_is_nova_controller?(node, role)
    return false if role.nil?

    _, controller_nodes, = role_expand_elements(role, "nova-controller")
    controller_nodes.include?(node)
  end

  def hyperv_available?
    return File.exist?("/opt/dell/chef/cookbooks/hyperv")
  end

  def network_present?(network_name)
    net_svc = NetworkService.new @logger
    network_proposal = Proposal.find_by(barclamp: net_svc.bc_name, name: "default")
    !network_proposal["attributes"]["network"]["networks"][network_name].nil?
  end
end
