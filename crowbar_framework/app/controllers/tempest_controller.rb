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

class TempestController < BarclampController
  def raise_not_found
    raise ActionController::RoutingError.new("Not Found")
  end

  def dashboard
    @test_runs = @service_object.get_test_runs
    @ready_nodes = @service_object.get_ready_nodes
    @nodes_hash = TempestService.get_all_nodes_hash
    render template: "barclamp/#{@bc_name}/dashboard.html.haml"
  end

  def test_runs
    # POST /tempest/test_runs/clear
    if (request.post? or request.put?) and params[:id] == "clear"
      @service_object.clear_test_runs
      flash[:notice] = t "barclamp.#{@bc_name}.dashboard.clear.success"

      respond_to do |format|
        format.json { render json: @test_runs }
        format.html { redirect_to tempest_dashboard_url }
      end

    # POST /tempest/test_runs
    elsif request.post? or request.put?
      begin
        test_run = @service_object.run_test params[:node]
        flash[:notice] = t "barclamp.#{@bc_name}.run.success", node: params[:node]
      rescue TempestService::ServiceError => error
        flash[:alert] = t "barclamp.#{@bc_name}.run.failure", node: params[:node], error: error

        respond_to do |format|
          format.json { render json: @test_runs }
          format.html { redirect_to tempest_dashboard_path }
        end
      end

      logger.debug "test run result: #{test_run.inspect}"
      respond_to do |format|
        # Does not work, a the results do not exist before run has finished
        # format.html { redirect_to "/#{@bc_name}/results/#{test_run['uuid']}.html" }
        format.html { redirect_to tempest_dashboard_url }
      end

    # GET /tempest/test_runs/<test-run-id>
    elsif uuid = params[:id]
      @test_run = @service_object.get_test_run_by_uuid(uuid) or raise_not_found
      respond_to do |format|
        format.json { render json: @test_result }
        format.html { redirect_to "/#{@bc_name}/results/#{uuid}.html" }
      end

    # GET /tempest/test_runs
    else
      @test_runs = @service_object.get_test_runs
      respond_to do |format|
        format.json { render json: @test_runs }
        format.html { redirect_to tempest_dashboard_path }
      end
    end
  end

  def _prepare_results_html(test_run)
    return if File.exist?(test_run["results.html"])

    xml = REXML::Document.new(IO.read(test_run["results.xml"]))
    File.open(test_run["results.html"], "w") { |out|
      out.write(
        render_to_string(template: "barclamp/#{@bc_name}/_results.html.haml",
          locals: {xml: xml }, layout: false))
    }
  end

  def results
    @test_run = @service_object.get_test_run_by_uuid(params[:id])
    raise_not_found if not @test_run or @test_run["status"] == "running"

    respond_to do |format|
      format.xml { render file: @test_run["results.xml"] }
      format.html {
        _prepare_results_html @test_run
        render template: "barclamp/#{@bc_name}/results.html.haml"
      }
    end
  end

  protected

  def initialize_service
    @service_object = TempestService.new logger
  end
end
