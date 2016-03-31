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

class NovaService < PacemakerServiceObject
  def initialize(thelogger)
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
            "suse" => "< 12.1",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "nova-compute-docker" => {
          "unique" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
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
            "suse" => "< 12.1",
            "windows" => "/.*/"
          },
          "remotes" => true
        },
        "nova-compute-qemu" => {
          "unique" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          },
          "remotes" => true
        },
        "nova-compute-vmware" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
        },
        "nova-compute-zvm" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.1",
            "windows" => "/.*/"
          }
        },
        "nova-compute-xen" => {
          "unique" => false,
          "count" => -1,
          "platform" => {
            "suse" => ">= 12.1",
          },
          "remotes" => true
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

    # do not use docker by default
    # do not use zvm by default
    #   TODO add it here once a compute node can run inside z/VM
    base["deployment"]["nova"]["elements"] = {
      "nova-controller" => [controller.name],
      "nova-compute-hyperv" => hyperv.map(&:name),
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
    base["attributes"]["nova"]["api_db"]["password"] = random_password
    base["attributes"]["nova"]["db"]["password"] = random_password
    base["attributes"]["nova"]["neutron_metadata_proxy_shared_secret"] = random_password

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
  def active_update(proposal, inst, in_queue)
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
    return if all_nodes.empty?

    unless hyperv_available?
      role.override_attributes["nova"]["elements"]["nova-compute-hyperv"] = []
    end

    controller_elements, controller_nodes, ha_enabled = role_expand_elements(role, "nova-controller")
    reset_sync_marks_on_clusters_founders(controller_elements)
    Openstack::HA.set_controller_role(controller_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["nova", "ha", "enabled"], ha_enabled, controller_elements, vip_networks)
    role.save if dirty

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    controller_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(controller_elements, vip_networks)

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

    compute_nodes_for_network.each do |n|
      neutron_service.enable_neutron_networks(neutron["attributes"]["neutron"],
                                              n, net_svc,
                                              neutron["attributes"]["neutron"]["use_dvr"])
    end unless all_nodes.nil?

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

    unless elements["nova-compute-hyperv"].empty? || hyperv_available?
      validation_error I18n.t("barclamp.#{@bc_name}.validation.hyperv_support")
    end

    elements["nova-compute-docker"].each do |n|
      nodes[n] += 1
    end unless elements["nova-compute-docker"].nil?
    elements["nova-compute-hyperv"].each do |n|
      nodes[n] += 1
    end unless elements["nova-compute-hyperv"].nil?
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
        platform: CrowbarService.pretty_target_platform(node_platform),
        arch: node["kernel"]["machine"]
      )
    end unless elements["nova-compute-xen"].nil?

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

    super
  end

  private

  def hyperv_available?
    return File.exist?("/opt/dell/chef/cookbooks/hyperv")
  end
end
