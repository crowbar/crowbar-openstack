# Copyright 2011, Dell 
# Copyright 2012, Dell
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

class TempestService < ServiceObject
  class ServiceError < StandardError
  end

  def initialize(thelogger)
    @bc_name = "tempest"
    @logger = thelogger
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

    nodes = NodeObject.find("roles:nova-multi-controller")
    nodes.delete_if { |n| n.nil? or n.admin? }
    unless nodes.empty?
      base["deployment"]["tempest"]["elements"] = {
        "tempest" => [ nodes.first.name ]
      }
    end

    base["attributes"]["tempest"]["nova_instance"] = ""
    begin
      novaService = NovaService.new(@logger)
      novas = novaService.list_active[1]
      if novas.empty?
        # No actives, look for proposals
        novas = novaService.proposals[1]
      end
      base["attributes"]["tempest"]["nova_instance"] = novas[0] unless novas.empty?
    rescue
      @logger.info("Tempest create_proposal: no nova found")
    end

    base["attributes"]["tempest"]["tempest_user_username"] = "tempest-user-" + random_password
    base["attributes"]["tempest"]["tempest_user_tenant"] = "tempest-tenant-" + random_password
    base["attributes"]["tempest"]["tempest_user_password"] = random_password

    @logger.debug("Tempest create_proposal: exiting")
    base
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("Tempest apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    # Update tempest_tarball path
    nodes = NodeObject.find("roles:provisioner-server")
    unless nodes.nil? or nodes.length < 1
      admin_ip = nodes[0].get_network_by_type("admin")["address"]
      web_port = nodes[0]["provisioner"]["web_port"]
      # substitute the admin web portal
      tempest_tarball_path = role.default_attributes["tempest"]["tempest_tarball"].gsub("<ADMINWEB>", "#{admin_ip}:#{web_port}")
      tempest_test_image_path = role.default_attributes["tempest"]["tempest_test_image"].gsub("<ADMINWEB>", "#{admin_ip}:#{web_port}")
      role.default_attributes["tempest"]["tempest_tarball"] = tempest_tarball_path
      role.default_attributes["tempest"]["tempest_test_image"] = tempest_test_image_path
    end

    role.save

    @logger.debug("Tempest apply_role_pre_chef_call: leaving")
  end

  def get_test_run_by_uuid(uuid)
    get_test_runs.each do |r|
        return r if r['uuid'] == uuid
    end
    nil
  end

  def self.get_all_nodes_hash
    Hash[ NodeObject.find_all_nodes.map {|n| [n.name, n]} ]
  end

  def get_ready_nodes
    nodes = get_ready_proposals.collect { |p| p.elements[@bc_name] }.flatten
    NodeObject.find_all_nodes.select { |n| nodes.include?(n.name) and n.status == "ready" }
  end

  def get_ready_proposals
    ProposalObject.find_proposals(@bc_name).select {|p| p.status == 'ready'}.compact
  end

  def _get_or_create_db
    db = ProposalObject.find_data_bag_item "crowbar/tempest"
    if db.nil?
      begin
        lock = acquire_lock @bc_name
      
        db_item = Chef::DataBagItem.new
        db_item.data_bag "crowbar"
        db_item["id"] = "tempest"
        db_item["test_runs"] = []
        db = ProposalObject.new db_item
        db.save
      ensure
        release_lock lock
      end
    end
    db
  end

  def get_test_runs
    _get_or_create_db["test_runs"]
  end

  def clear_test_runs
    tempest_db = _get_or_create_db

    tempest_db["test_runs"] = []
    lock = acquire_lock(@bc_name)
    tempest_db.save
    release_lock(lock)
  end

  def run_test(node)
    raise "failed to look up a tempest proposal applied to #{node.inspect}" if (proposal = _get_proposal_by_node node).nil?
    
    test_run_uuid = `uuidgen`.strip
    test_run = { 
      "uuid" => test_run_uuid, "started" => Time.now.utc.to_i, "ended" => nil, 
      "status" => "running", "node" => node, "results.xml" => "log/#{test_run_uuid}.xml"}

    tempest_db = _get_or_create_db

    lock = acquire_lock(@bc_name)
    tempest_db["test_runs"] << test_run
    tempest_db.save
    release_lock(lock)

    # TODO: add proposal_path as an editable parameter to the proposal
    proposal_path = '/opt/tempest'

    pid = fork do
      command_line = "python #{proposal_path}/run_tempest.py 2>/dev/null"
      Process.waitpid run_remote_chef_client(node, command_line, test_run["results.xml"])

      test_run["ended"] = Time.now.utc.to_i
      test_run["status"] = $?.exitstatus.equal?(0) ? "passed" : "failed"
      
      lock = acquire_lock(@bc_name)
      tempest_db.save
      release_lock(lock)
    end
    Process.detach pid
    test_run
  end

  def _get_proposal_by_node(node)
    get_ready_proposals.each do |p|
      return p if p.elements[@bc_name].include? node
    end
    nil
  end
end

