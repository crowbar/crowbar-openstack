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

  
  # remove test result specified by uuid
  def removeresult
    uuid = params[:id]
    f = @service_object.acquire_lock(@bc_name)
    prop_name = _get_proposal_name_from_result_uuid(uuid)
    if prop_name
      prop = ProposalObject.find_proposal(@bc_name, prop_name)
      prop.item["attributes"][@bc_name]["test_results"].delete_if{|result| result["uuid"]== uuid}
      prop.save
      cmd = "rm -f /opt/dell/crowbar_framework/log/*-#{uuid}.runtests.xml"
      @service_object.run_remote_chef_client("admin", cmd, "/dev/null") #TODO: perform admin node finding; define filename
    else
      Rails.logger.info "coudn't find any proposal contains result with specified uuid #{uuid} OR tests are still running"
    end
  ensure
    @service_object.release_lock(f)
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
      cmd_pid = @service_object.run_remote_chef_client(node_name, cmd, filename)
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
      prop.item["attributes"][@bc_name]["test_results"].each do |result|
        if result["uuid"] == uuid
          result.merge!({"ended" => ended, "status" => status })
          break
        end
      end
      prop.save
      @service_object.release_lock(f)
      Rails.logger.info "Runtests: leaving fork()"
    }
  end

  private

  def _get_proposal_name_from_node_name(name)
    ProposalObject.find_proposals(@bc_name).each do |prop|
      if prop.item["deployment"][@bc_name]["elements"][@bc_name].first == name
        return prop.name
      end
    end
    nil
  end

  def _get_proposal_name_from_result_uuid(uuid)
    ProposalObject.find_proposals(@bc_name).each do |prop|
      prop.item["attributes"][@bc_name]["test_results"].each do |result|
        if result["uuid"] == uuid
          if result["status"] != "running"
            return prop.name
          else
            return nil
          end
        end
      end
    end
    nil
  end

  def _uuid
    `uuidgen`.strip
  end

end
