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

  def raise_not_found
    raise ActionController::RoutingError.new('Not Found')
  end

  def dashboard
    @test_runs = @service_object.get_test_runs
    @ready_nodes = @service_object.get_ready_nodes
    @nodes_hash = TempestService.get_all_nodes_hash
    render :template => 'barclamp/tempest/dashboard.html.haml'
  end

  def test_runs
    if (request.post? or request.put?) and params[:id] == 'clear'
      @service_object.clear_test_runs
      redirect_to "/#{@bc_name}/dashboard" unless request.xhr?
    elsif request.post? or request.put?
      test_run = @service_object.run_test(params[:node])
      # TODO(aandreev): add flash[:notice]
      if request.xhr?
        # REST style interface has been called
        render :text => "/#{@bc_name}/test_runs/#{test_run["uuid"]}"
      else
        # it was a regular post submit
        redirect_to "/#{@bc_name}/dashboard"
      end
    elsif uuid = params[:id]
      @test_run = @service_object.get_test_run_by_uuid(uuid) or raise_not_found
      respond_to do |format|
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

  def _render_result_html(input_xml_name, output_html_name)
    input_xml = File.read(input_xml_name)
    output_html = File.open(output_html_name, "wb")
    doc, posts = REXML::Document.new(input_xml), []
    output_html.write(render_to_string(:template => 'barclamp/tempest/_xml_to_html.html.haml', :locals => {:doc => doc}))
    output_html.close()
  end

  def results
    test_run = @service_object.get_test_run_by_uuid(params[:id]) or raise_not_found
    results_html = "log/#{params[:id]}.html"

    respond_to do |format|
      format.xml { render :file => test_run["results.xml"] }
      format.html { if not File.exist?(results_html)
                      _render_result_html(test_run["results.xml"], results_html)
                    end
                    render :file => results_html
                  }
    end
  end
end
