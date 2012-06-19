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

  def self.return_404
    render :file => 'public/404.html', :status => 404
  end

  def dashboard
    @test_runs = @service_object.get_test_runs
    @ready_nodes = @service_object.get_ready_nodes
    @nodes_hash = TempestService.get_all_nodes_hash
    render :template => 'barclamp/tempest/dashboard.html.haml'
  end

  def test_runs
    if request.post? or request.put?
      test_run = @service_object.run_test(params[:node])
      if request.xhr?
        # REST style interface has been called
        render :text => url_for(:action => "test_runs", :id => test_run["uuid"])
      else
        # it was a regular post submit
        redirect_to url_for(:action => "dashboard")
      end
    elsif uuid = params[:id]
      @test_run = @service_object.get_test_run_by_uuid uuid
      respond_to do |format|
        format.any { TempestController.return_404 } unless @test_run
        format.json { render :json => @test_result } 
        format.html { render :template => 'barclamp/tempest/a_test_run.html.haml' }
      end
    else
      @test_runs = @service_object.get_test_runs
      respond_to do |format|
        format.json { render :json => @test_runs }
        format.html { render :template => 'barclamp/tempest/_test_runs.html.haml', :layout => false }
      end
    end
  end

  def results
    test_run = @service_object.get_test_run_by_uuid params[:id]
    respond_to do |format|
      format.any { TempestController.return_404 } unless @test_run
      format.xml { render :file => test_run["results.xml"] }
    end
  end
end
