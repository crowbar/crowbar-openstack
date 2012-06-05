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

class TempestController < BarclampController
  def initialize
    @service_object = TempestService.new logger
  end


  # run tempest test and store test results in xml xunit format in log directory on admin node
  def runtests
    node_name = params[:id] # do we need to check node name?
    uuid = _uuid
    Rails.logger.info "Runtests: will run tempest on #{node_name} node"
    filename = "log/#{node_name}-#{uuid}.runtests.xml"
    render :nothing => true
    Rails.logger.info "Runtests: leaving runtests and forking"
    Kernel::fork {
      Rails.logger.info "Runtests: enrering fork(), starting nosetests on #{node_name} node"
      cmd = "nosetests -q -w /opt/tempest/ tempest.tests.test_authorization --with-xunit --xunit-file=/dev/stdout 1>&2 2>/dev/null"
      cmd_pid = @service_object.run_remote_chef_client(node_name, cmd , filename)
      # update proposal test_results: "status" => "running"
      status = "running"
      started = Time.now.to_s
      prop_name = _get_proposal_name_from_node_name(node_name)
      f = @service_object.acquire_lock(@bc_name)
      prop = ProposalObject.find_proposal(@bc_name, prop_name)
      prop.item["attributes"][@bc_name]["test_results"] << { "uuid" => uuid, "started" => started, "ended" => "none", "status" => status }
      prop.save
      @service_object.release_lock(f)
      Rails.logger.info "Runtests: wating for the pid #{cmd_pid}"
      Process::waitpid(cmd_pid)
      ended = Time.now.to_s
      if 0 == $?.exitstatus
        status = "passed"
      else
        status = "failed"
      # update proposal again
      f = @service_object.acquire_lock(@bc_name)
      prop = ProposalObject.find_proposal(@bc_name, prop_name)
      results_set = prop.item["attributes"][@bc_name]["test_results"].select{ |result| result["uuid"] == uuid }
      results_set.each do |result|
        result.merge({"ended" => ended, "status" => status })
      end
      prop.save
      @service_object.release_lock(f)
      Rails.logger.info "Runtests: leaving fork()"
    }
  end

  private

  def _get_proposal_name_from_node_name(name)
    proposal = ProposalObject.find_proposals(@bc_name).select{ |prop| prop.item["deployment"][@bc_name]["elements"][@bc_name].first == name }
    proposal.name
  end

  def _uuid
    `uuidgen`.strip
  end

end
