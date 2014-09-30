#
# Cookbook Name:: nvp
# Provider:: transport_node
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

require 'json'
require 'openssl'

def whyrun_supported?
  true
end

def create_connection(controller)
  begin
    require 'faraday'
  rescue LoadError
    Chef::Log.error "Missing gem 'faraday'. Use the default nvp recipe to install it first."
  end

  conn = Faraday.new(url: "https://#{controller[:host]}:#{controller[:port]}", ssl: { verify: false }) do |faraday|
    faraday.request  :url_encoded
    faraday.response :logger
    faraday.adapter  Faraday.default_adapter
  end

  resp = conn.post '/ws.v1/login', username: controller[:username], password: controller[:password]
  Chef::Log.error(resp.body) unless resp.status == 200

  cookie = resp.headers['set-cookie'].split(';').first

  [conn, cookie]
end

action :create do
  client_pem = @new_resource.client_pem ||
               ::OpenSSL::X509::Certificate.new(::File.read(@new_resource.client_pem_file)).to_s
  Chef::Log.debug "Client PEM: #{client_pem}"

  unless @current_resource.exists # create

    converge_by "creating transport node #{@new_resource.name}" do

      conn, cookie = create_connection @new_resource.nvp_controller
      
      tnode = {}
      tnode['display_name'] = @new_resource.name
      tnode['integration_bridge_id'] = @new_resource.integration_bridge_id
      tnode['transport_connectors'] = @new_resource.transport_connectors
      tnode['credential'] = {
        'client_certificate' => {
          'pem_encoded' => client_pem
        },
        'type' => 'SecurityCertificateCredential'
      }

      resp = conn.post "/ws.v1/transport-node" do |req|
        req.headers['Cookie'] = cookie
        req.headers['Content-Type'] = 'application/json'
        req.body = tnode.to_json
      end
      Chef::Log.error(resp.body) unless resp.status == 201 # Created
    end
    @new_resource.updated_by_last_action(true)

  else # exists => update?
    unless @new_resource.integration_bridge_id == @current_resource.integration_bridge_id and
           @new_resource.tunnel_probe_random_vlan == @current_resource.tunnel_probe_random_vlan and
           @new_resource.transport_connectors.first.map {|k,v| @current_resource.transport_connectors.first[k] == v }.all? and
           client_pem == @current_resource.client_pem

      Chef::Log.info "#{@new_resource.integration_bridge_id} <==> #{@current_resource.integration_bridge_id}"
      Chef::Log.info "#{@new_resource.transport_connectors} <==> #{@current_resource.transport_connectors}"
      Chef::Log.info "#{@new_resource.tunnel_probe_random_vlan} <==> #{@current_resource.tunnel_probe_random_vlan}"
      Chef::Log.info "#{client_pem.inspect} <==> #{@current_resource.client_pem.inspect}"

      converge_by "updating existing transport node #{@new_resource.name}" do
        conn, cookie = create_connection @new_resource.nvp_controller

        tnode = {}
        tnode['display_name'] = @new_resource.name
        tnode['integration_bridge_id'] = @new_resource.integration_bridge_id
        tnode['transport_connectors'] = @new_resource.transport_connectors
        tnode['credential'] = {
          'client_certificate' => {
            'pem_encoded' => client_pem
          },
          'type' => 'SecurityCertificateCredential'
        }

        resp = conn.put "/ws.v1/transport-node/#{@current_resource.uuid}" do |req|
          req.headers['Cookie'] = cookie
          req.headers['Content-Type'] = 'application/json'
          req.body = tnode.to_json
        end
        Chef::Log.error(resp.body) unless resp.status == 200 # OK
      end
      @new_resource.updated_by_last_action true
    end
  end
end

action :delete do
  if @current_resource.exists

    converge_by "delete transport node #{@new_resource.name}" do
      conn, cookie = create_connection @new_resource.nvp_controller

      resp = conn.delete "/ws.v1/transport-node/#{@current_resource.uuid}" do |req|
        req.headers['Cookie'] = cookie
      end
      Chef::Log.error(resp.body) unless resp.status == 204 # No Content
    end

    @new_resource.updated_by_last_action true
  else
    Chef::Log.info "transport node #{@new_resource.name} does not exist, nothing to do"
  end
end

def load_current_resource
  @current_resource = Chef::Resource::NvpTransportNode.new(@new_resource.name)

  conn, cookie = create_connection @new_resource.nvp_controller

  resp = conn.get '/ws.v1/transport-node', display_name: @new_resource.name, fields: '*' do |req|
    req.headers['Cookie'] = cookie
  end
  Chef::Log.error(resp.body) unless resp.status == 200
  data = JSON::parse resp.body

  if data['result_count'] == 0
    Chef::Log.debug "No transport node with display_name #{@new_resource.name} found"
  elsif data['result_count'] > 1
    Chef::Log.info "More than one transport nodes with display_name #{@new_resource.name} found -- this means trouble"
  else
    Chef::Log.debug "One transport node with display_name #{@new_resource.name}"

    tnode = data['results'].first

    @current_resource.integration_bridge_id tnode['integration_bridge_id']
    @current_resource.transport_connectors tnode['transport_connectors']
    @current_resource.client_pem tnode['credential']['client_certificate']['pem_encoded']
    @current_resource.tunnel_probe_random_vlan tnode['tunnel_probe_random_vlan']
    @current_resource.uuid = tnode['uuid'] # save for eventual update
    @current_resource.exists = true
  end

  @current_resource
end
