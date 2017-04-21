#
# Copyright 2016, SUSE Linux GmbH
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

class Api::OpenstackController < ApiController
  api :GET, "/api/openstack", "List all Openstack components"
  api_version "2.0"
  def index
    render json: [], status: :not_implemented
  end

  api :GET, "/api/openstack/:name", "Show a single Openstack component"
  param :name, String, desc: "OpenStack component", required: true
  api_version "2.0"
  def show
    render json: {}, status: :not_implemented
  end

  api :POST, "/api/openstack/backup", "Create a backup of Openstack"
  api_version "2.0"
  def backup
    # FIXME: fake the nodes_db_dump step for now until it is implemented
    nodes_db_dump = ::Crowbar::UpgradeStatus.new
    nodes_db_dump.start_step(:nodes_db_dump)
    nodes_db_dump.end_step
    head :ok
  rescue Crowbar::Error::StartStepRunningError,
         Crowbar::Error::StartStepOrderError,
         Crowbar::Error::EndStepRunningError => e
    render json: {
      errors: {
        nodes_db_dump: {
          data: e.message,
          help: "Please refer to the error message in the response."
        }
      }
    }, status: :unprocessable_entity
  end

  api :POST, "/api/openstack/services", "Stop all Openstack services on a node"
  api_version "2.0"
  param :id, Integer, desc: "Node ID", required: true
  def services
    head :not_implemented
  end
end
