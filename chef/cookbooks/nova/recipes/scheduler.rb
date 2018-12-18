#
# Cookbook Name:: nova
# Recipe:: scheduler
#
# Copyright 2010, Opscode, Inc.
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

include_recipe "nova::config"

use_crowbar_pacemaker_service = node[:nova][:ha][:enabled] &&
  node[:pacemaker][:clone_stateless_services]

nova_package "conductor" do
  use_pacemaker_provider use_crowbar_pacemaker_service
end

nova_package "scheduler" do
  use_pacemaker_provider use_crowbar_pacemaker_service
end
