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
require "rexml/document"
include ERB::Util # for html_escape

class SwiftService < OpenstackServiceObject
  class ServiceError < StandardError
  end

  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "swift"
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "swift-storage" => {
          "unique" => false,
          "count" => -1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          }
        },
        "swift-proxy" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "swift-dispersion" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          }
        },
        "swift-ring-compute" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.3",
            "windows" => "/.*/"
          }
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer << { "barclamp" => "keystone", "inst" => role.default_attributes["swift"]["keystone_instance"] }
    answer
  end

  def create_proposal
    base = super

    base[:attributes][:swift][:cluster_hash] = "%x%s" %  [rand(100000),rand(100000)]

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? or n.admin? }

    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")

    unless base["attributes"][@bc_name]["keystone_instance"].blank?
      base["attributes"]["swift"]["auth_method"] = "keystone"
    end

    base["attributes"]["swift"]["service_password"] = random_password
    base["attributes"]["swift"]["dispersion"]["service_password"] = random_password
    base["attributes"]["swift"]["container_sync"]["key"] = random_password
    base["attributes"]["swift"]["container_sync"]["key2"] = random_password

    base["deployment"]["swift"]["elements"] = {
        "swift-proxy" => [],
        "swift-ring-compute" => [],
        "swift-storage" => []
    }

    if nodes.size > 0
      controller        = nodes.detect { |n| n if n.intended_role == "controller" } || nodes.shift
      storage_nodes     = nodes.select { |n| n if n.intended_role == "storage" }
      if storage_nodes.empty?
        storage_nodes = nodes.select { |n| n if n.intended_role != "controller" }
      end
      base["deployment"]["swift"]["elements"] = {
        "swift-dispersion"      => [controller[:fqdn]],
        "swift-proxy"           => [controller[:fqdn]],
        "swift-ring-compute"    => [controller[:fqdn]],
        "swift-storage"         => storage_nodes.map { |x| x[:fqdn] }
      }
    end

    @logger.fatal("swift create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Swift apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    proxy_elements, proxy_nodes, ha_enabled = role_expand_elements(role, "swift-proxy")
    Openstack::HA.set_controller_role(proxy_nodes) if ha_enabled

    vip_networks = ["admin", "public"]

    dirty = false
    dirty = prepare_role_for_ha_with_haproxy(role, ["swift", "ha", "enabled"], ha_enabled, proxy_elements, vip_networks)
    role.save if dirty

    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    net_svc = NetworkService.new @logger
    proxy_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    all_nodes.each do |n|
      net_svc.allocate_ip "default", "storage", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(proxy_elements, vip_networks)

    @logger.debug("Swift apply_role_pre_chef_call: leaving")
  end

  def get_report_run_by_uuid(uuid)
    get_dispersion_reports.each do |r|
        return r if r["uuid"] == uuid
    end
    nil
  end

  def get_all_nodes_hash
    Hash[NodeObject.find_all_nodes.map { |n| [n.name, n] }]
  end

  def get_ready_nodes
    nodes = get_ready_proposals.collect { |p| p.elements["#{@bc_name}-dispersion"] }.flatten
    NodeObject.find_all_nodes.select { |n| nodes.include?(n.name) and n.ready? }
  end

  def get_ready_proposals
    Proposal.where(barclamp: @bc_name).select { |p| p.status == "ready" }.compact
  end

  def _get_or_create_db
    db = Chef::DataBag.load("crowbar/swift") rescue nil
    if db.nil?
      with_lock @bc_name do
        db = Chef::DataBagItem.new
        db.data_bag "crowbar"
        db["id"] = "swift"
        db["dispersion_reports"] = []
        db.save
      end
    end
    db
  end

  def get_dispersion_reports
    sorted = _get_or_create_db["dispersion_reports"].sort do |x, y|
      y["started"] <=> x["started"]
    end

    sorted.map do |report|
      if report["ended"].is_a? Integer
        report["ended"] = Time.at report["ended"]
      end

      if report["started"].is_a? Integer
        report["started"] = Time.at report["started"]
      end

      report
    end
  end

  def clear_dispersion_reports
    def delete_file(file_name)
      File.delete(file_name) if File.exist?(file_name)
    end

    def process_exists(pid)
      begin
        Process.getpgid( pid )
        true
      rescue Errno::ESRCH
        false
      end
    end

    swift_db = _get_or_create_db

    @logger.info("cleaning out report runs and results")
    swift_db["dispersion_reports"].delete_if do |report_run|
      if report_run["status"] == "running"
        if report_run["pid"] and not process_exists(report_run["pid"])
          @logger.warn("running dispersion run #{report_run['uuid']} seems to be stale")
        elsif Time.now.utc.to_i - report_run["started"] > 60 * 60 * 4 # older than 4 hours
          @logger.warn("running dispersion run #{report_run['uuid']} seems to be outdated, started at #{Time.at(report_run['started']).to_s}")
        else
          @logger.debug("omitting running dispersion run #{report_run['uuid']} while cleaning")
          next
        end
      else
        delete_file(report_run["results.html"])
        delete_file(report_run["results.json"])
      end
      @logger.debug("removing dispersion run #{report_run['uuid']}")
      true
    end

    with_lock @bc_name do
      swift_db.save
    end
  end

  def run_report(node)
    raise "unable to look up a #{@bc_name} proposal applied to #{node.inspect}" if (proposal = _get_proposal_by_node node).nil?

    report_run_uuid = `uuidgen`.strip
    report_run = {
      "uuid" => report_run_uuid, "started" => Time.now.utc.to_i, "ended" => nil, "pid" => nil,
      "status" => "running", "node" => node, "results.json" => "log/#{report_run_uuid}.json",
      "results.html" => "log/#{report_run_uuid}.html"}

    swift_db = _get_or_create_db

    swift_db["dispersion_reports"].each do |dr|
      raise ServiceError, I18n.t("barclamp.#{@bc_name}.run.duplicate") if dr["node"] == node and dr["status"] == "running"
    end

    with_lock @bc_name do
      swift_db["dispersion_reports"] << report_run
      swift_db.save
    end

    nobj = NodeObject.find_node_by_name(node)
    swift_user = nobj[@bc_name]["user"]
    @logger.info("starting dispersion-report on node #{node}, report run uuid #{report_run['uuid']}")

    pid = fork do
      command_line = "sudo -u #{swift_user} EVENTLET_NO_GREENDNS=yes swift-dispersion-report -j 2>/dev/null"
      Process.waitpid run_remote_chef_client(node, command_line, report_run["results.json"])

      report_run["ended"] = Time.now.utc.to_i
      report_run["status"] = $?.exitstatus.equal?(0) ? "passed" : "failed"
      report_run["pid"] = nil

      with_lock @bc_name do
        swift_db.save
      end

      @logger.info("report run #{report_run['uuid']} complete, status '#{report_run['status']}'")
    end
    Process.detach pid

    # saving the PID to prevent
    report_run["pid"] = pid
    with_lock @bc_name do
      swift_db.save
    end
    report_run
  end

  def _get_proposal_by_node(node)
    get_ready_proposals.each do |p|
      return p if p.elements["#{@bc_name}-dispersion"].include? node
    end
    nil
  end

  def validate_proposal_after_save(proposal)
    # first, check for conflict with ceph
    Proposal.where(barclamp: "ceph").each {|p|
      next unless (p.status == "ready") || (p.status == "pending")
      ceph_role = p.role
      elements = (p.status == "ready" && !ceph_role.nil?) ? ceph_role.elements : p.elements
      if elements.keys.include?("ceph-radosgw") && !elements["ceph-radosgw"].empty?
        @logger.warn("node #{elements['ceph-radosgw']} has ceph-radosgw role")
        validation_error I18n.t("barclamp.#{@bc_name}.validation.radosgw")
      end
    }

    validate_one_for_role proposal, "swift-proxy"
    validate_one_for_role proposal, "swift-ring-compute"
    validate_at_least_n_for_role proposal, "swift-storage", 1

    if proposal["attributes"]["swift"]["replicas"] <= 0
      validation_error I18n.t("barclamp.#{@bc_name}.validation.replica")
    end

    elements = proposal["deployment"]["swift"]["elements"]

    if elements["swift-storage"].length < proposal["attributes"]["swift"]["zones"]
      if elements["swift-storage"].length == 1
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.zone",
          swift_storage: elements["swift-storage"].length,
          swift_zone: proposal["attributes"]["swift"]["zones"]
        )
      else
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.zones",
          swift_storage: elements["swift-storage"].length,
          swift_zone: proposal["attributes"]["swift"]["zones"]
        )
      end
    end

    middlewares = proposal["attributes"]["swift"]["middlewares"]
    if (middlewares["tempurl"]["enabled"] || middlewares["staticweb"]["enabled"] || middlewares["formpost"]["enabled"])
      unless proposal["attributes"]["swift"]["keystone_delay_auth_decision"]
        validation_error I18n.t("barclamp.#{@bc_name}.validation.public_containers")
      end
    end

    middlewares["crossdomain"]["cross_domain_policy"].split("\n").each do |line|
      begin
        REXML::Document.new(line)
      rescue REXML::ParseException
        validation_error I18n.t(
          "barclamp.#{@bc_name}.validation.no_valid_xml", html_escape: html_escape(line)
        )
      end
    end

    super
  end
end
