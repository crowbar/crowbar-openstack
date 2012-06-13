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


  def download
    uuid = params[:id]
    if /^[0-9A-Fa-f]{8}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{4}\-[0-9A-Fa-f]{12}/.match(uuid)
      send_file("#{Rails.root}/log/#{uuid}.run_tests.xml", :filename => "run_tests.#{uuid[0, 7]}.xml", :type => "application/xml")
    else
      render :nothing => true, :status => '404'
    end
  end

  # get all test results
  def get_results 
    results = []
    nodes = []
    ProposalObject.find_proposals(@bc_name).each do |prop|
      nodes.concat(prop.elements[@bc_name].map{|node| node.split('.').first}) if prop.status == "ready"
      results.concat(prop.item["attributes"][@bc_name]["test_results"])
    end
    Rails.logger.info "Get results: results=#{results.inspect}, nodes=#{nodes.inspect}"
    respond_to do |format|
      format.json { render :json => results }
      format.html { render :template => 'barclamp/tempest/index.html.haml', :locals => {:results => results.sort{|x,y| x["started"] <=> y["started"]}, :nodes => nodes } }
    end
  end


  # remove all ended test results and xml-s
  def remove_results
    f = @service_object.acquire_lock(@bc_name)
    ProposalObject.find_proposals(@bc_name).each do |prop|
      prop.item["attributes"][@bc_name]["test_results"].reject{|result| result["status"] == "running" }.each do |result|
        filename = "#{Rails.root}/log/#{result["uuid"]}.run_tests.xml"
        begin
          File.delete filename
        rescue
          Rails.logger.info "Remove results: can't delete file #{filename}"
        end
      end
      prop.item["attributes"][@bc_name]["test_results"].delete_if{|result| result["status"] != "running"}
      prop.save
    end
    Rails.logger.info "Remove results: all non running test results/logs have been removed"
    flash[:notice] = t('.succeeded', :scope=>'barclamp.tempest.remove_results')
    redirect_to :back
  ensure
    @service_object.release_lock(f)
  end

  
  # remove test result specified by uuid
  def remove_result
    uuid = params[:id]
    f = @service_object.acquire_lock(@bc_name)
    prop_name = _get_proposal_name_from_result_uuid(uuid)
    if prop_name
      prop = ProposalObject.find_proposal(@bc_name, prop_name)
      prop.item["attributes"][@bc_name]["test_results"].delete_if{|result| result["uuid"]== uuid}
      prop.save
      Rails.logger.info "Remove result: item with uuid #{uuid} removed"
      filename = "#{Rails.root}/log/#{uuid}.run_tests.xml"
      begin
        File.delete filename
      rescue
        Rails.logger.info "Remove results: can't delete file #{filename}"
      end
      flash[:notice] = t('.succeeded', :scope=>'barclamp.tempest.remove_result') + ": " + uuid[0, 7]
    else
      Rails.logger.info "Remove result: coudn't find any proposal contains result with specified uuid #{uuid} OR tests are still running"
      flash[:notice] = t('.failed', :scope=>'barclamp.tempest.remove_result') + ": " + uuid[0, 7]
    end
    redirect_to :back
  ensure
    @service_object.release_lock(f)
  end


  # run tempest test and store test results in xml xunit format in log directory on admin node
  def run_tests
    node_name = params[:id] # do we need to check node name?
    uuid = _uuid
    Rails.logger.info "Run tests: will run tempest on #{node_name} node"
    filename = "log/#{uuid}.run_tests.xml"
    prop_name = _get_proposal_name_from_node_name(node_name)
    if not prop_name
      Rails.logger.info "Run tests: couldn't find tempest proposal for node #{node_name}"
      flash[:notice] = t('.failed', :scope=>'barclamp.tempest.run_tests') + ": " + node_name 
      return redirect_to :back
    end
    flash[:notice] = t('.succeeded', :scope=>'barclamp.tempest.run_tests') + ": " + uuid[0, 7]
    Rails.logger.info "Run tests: leaving run_tests and forking"
    Kernel::fork {
      Rails.logger.info "Run tests: enrering fork() for starting nosetests on #{node_name} node"
      cmd = "nosetests -q -w /opt/tempest/ tempest.tests.test_authorization --with-xunit --xunit-file=/dev/stdout 1>&2 2>/dev/null"
      Rails.logger.info "Run tests: starting nosetests on #{node_name}"
      cmd_pid = @service_object.run_remote_chef_client(node_name, cmd, filename)
      # update proposal test_results: "status" => "running"
      status = "running"
      started = Time.now.to_s
      f = @service_object.acquire_lock(@bc_name)
      prop = ProposalObject.find_proposal(@bc_name, prop_name)
      prop.item["attributes"][@bc_name]["test_results"] << { "uuid" => uuid, "started" => started, "ended" => "none", "status" => status }
      prop.save
      @service_object.release_lock(f)
      Rails.logger.info "Run tests: wating for the pid #{cmd_pid}"
      Process::waitpid(cmd_pid)
      ended = Time.now.to_s
      if 0 == $?.exitstatus
        status = "passed"
      else
        status = "failed"
      end
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
      Rails.logger.info "Run tests: leaving fork()"
    }
    redirect_to :back
  end

  private

  def _get_proposal_name_from_node_name(name)
    ProposalObject.find_proposals(@bc_name).each do |prop|
      if prop.elements[@bc_name].map{|node| node.split('.').first}.include?(name)
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
