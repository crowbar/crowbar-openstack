# Copyright 2017 SUSE, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe "crowbar-pacemaker::haproxy"

haproxy_loadbalancer "ec2-api" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_api]
  use_ssl node[:nova]["ec2-api"][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_api"
  )
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "ec2-metadata" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_metadata]
  use_ssl node[:nova]["ec2-api"][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_metadata"
  )
  action :nothing
end.run_action(:create)

haproxy_loadbalancer "ec2-s3" do
  address "0.0.0.0"
  port node[:nova][:ports][:ec2_s3]
  use_ssl node[:nova]["ec2-api"][:ssl][:enabled]
  servers CrowbarPacemakerHelper.haproxy_servers_for_service(
    node, "nova", "ec2-api", "ec2_s3"
  )
  action :nothing
end.run_action(:create)
