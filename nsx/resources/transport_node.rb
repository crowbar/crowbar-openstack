#
# Cookbook Name:: nvp
# Resource:: transport_node
#
# Copyright 2013, cloudbau GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

actions :create, :delete
default_action :create

attribute :display_name, :kind_of => String, :name_attribute => true
attribute :nvp_controller, :kind_of => Hash, :required => true
attribute :transport_connectors, :kind_of => [Array, Hash], :default => []
#  E.g.
#  [
#     {
#       "transport_zone_uuid": "b9db1ed0-b214-4f29-a40d-1d4e59e2f209", 
#       "ip_address": "10.10.1.2", 
#       "type": "STTConnector"
#     }
#  ]

attribute :integration_bridge_id, :kind_of => String, :required => true
attribute :client_pem, :kind_of => String #, :required => true
attribute :client_pem_file, :kind_of => String
attribute :tunnel_probe_random_vlan, :kind_of => [TrueClass, FalseClass], :default => false
attribute :uuid, :kind_of => String, :required => false # remember what to update/delete
attribute :exists, :kind_of => [TrueClass, FalseClass], :default => false

attr_accessor :exists, :uuid
