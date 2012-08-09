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
require "rexml/document"

class TempestController < BarclampController
  def initialize
    @service_object = TempestService.new logger
  end

  def raise_not_found
    raise ActionController::RoutingError.new('Not Found')
  end

  def dashboard
    @test_runs = @service_object.get_test_runs
    @ready_nodes = @service_object.get_ready_nodes
    @nodes_hash = TempestService.get_all_nodes_hash
    render :template => "barclamp/#{@bc_name}/dashboard.html.haml"
  end

  def test_runs
    # POST /tempest/test_runs/clear
    if (request.post? or request.put?) and params[:id] == 'clear'
      @service_object.clear_test_runs
      flash[:notice] = t "barclamp.#{@bc_name}.dashboard.clear.success"
    # POST /tempest/test_runs
    elsif request.post? or request.put?
      begin
        test_run = @service_object.run_test params[:node]
        flash[:notice] = t "barclamp.#{@bc_name}.run.success", :node => params[:node]
      rescue TempestService::ServiceError => error
        flash[:notice] = t "barclamp.#{@bc_name}.run.failure", :node => params[:node], :error => error
      end
      
      # supporting REST style interface
      render :text => "/#{@bc_name}/test_runs/#{test_run["uuid"]}" if request.xhr?
    
    # GET /tempest/test_runs/<test-run-id>
    elsif uuid = params[:id] 
      @test_run = @service_object.get_test_run_by_uuid(uuid) or raise_not_found
      respond_to do |format|
        format.json { render :json => @test_result } 
        format.html { redirect_to "/#{@bc_name}/results/#{uuid}.html" }
      end
    
    # GET /tempest/test_runs
    else 
      @test_runs = @service_object.get_test_runs
      respond_to do |format|
        format.json { render :json => @test_runs }
        format.html { nil } # redirect to dashboard
      end
    end 
    redirect_to "/#{@bc_name}/dashboard" unless request.xhr?
  end

  def _prepare_results_html(test_run)
    return if File.exist?(test_run['results.html'])
    
    xml = REXML::Document.new(IO.read(test_run['results.xml']))
    File.open(test_run['results.html'], "w") { |out| 
      out.write(
        render_to_string(:template => "barclamp/#{@bc_name}/_results.html.haml",
          :locals => {:xml => xml }, :layout => false))
    }
  end

  def results
    @test_run = @service_object.get_test_run_by_uuid(params[:id])
    raise_not_found if not @test_run or @test_run['status'] == 'running'

    respond_to do |format|
      format.xml { render :file => @test_run['results.xml'] }
      format.html { 
        _prepare_results_html @test_run
        render :template => "barclamp/#{@bc_name}/results.html.haml"
      }
    end
  end
end
