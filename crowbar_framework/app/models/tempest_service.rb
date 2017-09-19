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

class TempestService < ServiceObject
  class ServiceError < StandardError
  end

  def initialize(thelogger = nil)
    @bc_name = "tempest"
    @logger = thelogger
  end

  class << self
    def role_constraints
      {
        "tempest" => {
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
    answer << { "barclamp" => "nova", "inst" => role.default_attributes["tempest"]["nova_instance"] }
    answer
  end

  def create_proposal
    # TODO: ensure that only one proposal can be applied to a node
    @logger.debug("Tempest create_proposal: entering")
    base = super
    @logger.debug("Tempest create_proposal: leaving base part")

    nodes = NodeObject.find("roles:nova-controller")
    nodes.delete_if { |n| n.nil? or n.admin? }
    unless nodes.empty?
      base["deployment"]["tempest"]["elements"] = {
        "tempest" => [nodes.first.name]
      }
    end

    base["attributes"][@bc_name]["nova_instance"] = find_dep_proposal("nova")

    base["attributes"]["tempest"]["tempest_user_username"] = "tempest-user-" + random_password
    base["attributes"]["tempest"]["tempest_adm_username"] = "tempest-adm-" + random_password
    base["attributes"]["tempest"]["tempest_user_tenant"] = "tempest-tenant-" + random_password
    base["attributes"]["tempest"]["tempest_user_password"] = random_password
    base["attributes"]["tempest"]["tempest_adm_password"] = random_password

    @logger.debug("Tempest create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "tempest"

    ks_svc = KeystoneService.new @logger
    keystone = Proposal.find_by(barclamp: ks_svc.bc_name)

    unless keystone[:attributes][:keystone][:default][:create_user]
      validation_error I18n.t("barclamp.#{@bc_name}.validation.no_alt_user")
    end

    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Tempest apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    # Update tempest_testimage path
    nodes = NodeObject.find("roles:provisioner-server")
    unless nodes.nil? or nodes.length < 1
      admin_ip = nodes[0].get_network_by_type("admin")["address"]
      web_port = nodes[0]["provisioner"]["web_port"]
      # substitute the admin web portal
      role.default_attributes["tempest"]["tempest_test_images"].each do |img_arch, img_path|
        img_path = img_path.gsub("<ADMINWEB>", "#{admin_ip}:#{web_port}")
        role.default_attributes["tempest"]["tempest_test_images"][img_arch] = img_path
      end
    end

    role.save

    # Allocate a public IP, tempest needs it
    net_svc = NetworkService.new @logger
    all_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    @logger.debug("Tempest apply_role_pre_chef_call: leaving")
  end

  def get_test_run_by_uuid(uuid)
    get_test_runs.each do |r|
        return r if r["uuid"] == uuid
    end
    nil
  end

  def self.get_all_nodes_hash
    Hash[NodeObject.find_all_nodes.map { |n| [n.name, n] }]
  end

  def get_ready_nodes
    nodes = get_ready_proposals.collect { |p| p.elements[@bc_name] }.flatten
    NodeObject.find_all_nodes.select { |n| nodes.include?(n.name) and n.ready? }
  end

  def get_ready_proposals
    Proposal.where(barclamp: @bc_name).all.select { |p| p.status == "ready" }.compact
  end

  def _get_or_create_db
    db = Chef::DataBag.load "crowbar/#{@bc_name}" rescue nil
    if db.nil?
      with_lock @bc_name do
        db = Chef::DataBagItem.new
        db.data_bag "crowbar"
        db["id"] = @bc_name
        db["test_runs"] = []
        db.save
      end
    end
    db
  end

  def get_test_runs
    _get_or_create_db["test_runs"]
  end

  def clear_test_runs
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

    tempest_db = _get_or_create_db

    @logger.info("cleaning out test runs and results")
    tempest_db["test_runs"].delete_if do |test_run|
      if test_run["status"] == "running"
        if test_run["pid"] and not process_exists(test_run["pid"])
          @logger.warn("running tempest run #{test_run['uuid']} seems to be stale")
        elsif Time.now.utc.to_i - test_run["started"] > 60 * 60 * 4 # older than 4 hours
          @logger.warn("running tempest run #{test_run['uuid']} seems to be outdated, started at #{Time.at(test_run['started']).to_s}")
        else
          @logger.debug("omitting running test run #{test_run['uuid']} while cleaning")
          next
        end
      else
        delete_file(test_run["results.html"])
        delete_file(test_run["results.xml"])
      end
      @logger.debug("removing tempest run #{test_run['uuid']}")
      true
    end

    with_lock @bc_name do
      tempest_db.save
    end
  end

  def run_test(node)
    raise "unable to look up a #{@bc_name} proposal at node #{node.inspect}" if (proposal = _get_proposal_by_node node).nil?

    test_run_uuid = `uuidgen`.strip
    test_run = {
      "uuid" => test_run_uuid, "started" => Time.now.utc.to_i, "ended" => nil, "pid" => nil,
      "status" => "running", "node" => node, "results.xml" => "log/#{test_run_uuid}.xml",
      "results.html" => "log/#{test_run_uuid}.html"}

    tempest_db = _get_or_create_db

    tempest_db["test_runs"].each do |tr|
      raise ServiceError, I18n.t("barclamp.#{@bc_name}.run.duplicate") if tr["node"] == node and tr["status"] == "running"
    end

    with_lock @bc_name do
      tempest_db["test_runs"] << test_run
      tempest_db.save
    end

    @logger.info("starting tempest on node #{node}, test run uuid #{test_run['uuid']}")

    pid = fork do
      command_line = "/tmp/tempest_smoketest.sh 2>/dev/null"
      Process.waitpid run_remote_chef_client(node, command_line, test_run["results.xml"])

      test_run["ended"] = Time.now.utc.to_i
      test_run["status"] = $?.exitstatus.equal?(0) ? "passed" : "failed"
      test_run["pid"] = nil

      with_lock @bc_name do
        tempest_db.save
      end

      @logger.info("test run #{test_run['uuid']} complete, status '#{test_run['status']}'")
    end
    Process.detach pid

    # saving the PID to prevent
    test_run["pid"] = pid
    with_lock @bc_name do
      tempest_db.save
    end
    test_run
  end

  def _get_proposal_by_node(node)
    get_ready_proposals.each do |p|
      return p if p.elements[@bc_name].include? node
    end
    nil
  end
end
