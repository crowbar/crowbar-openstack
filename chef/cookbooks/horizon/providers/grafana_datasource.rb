# Copyright 2017 SUSE Linux GmbH
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

require "json"
require "net/http"
require "openssl"
require "uri"

action :create do
  connection = _build_connection(new_resource)
  datasources = list_data_sources(connection)

  datasource = find_data_source_by_name(new_resource.name, datasources)

  payload = _datasource_payload(new_resource)

  send_datasource(connection, payload) if datasource.nil?

  if !datasource.nil? && datasource_diff?(datasource, payload)
    payload["id"] = datasource["id"]
    send_datasource(connection, payload)
  end
end

def list_data_sources(conn)
  path = ::File.join(conn["base_path"], "/api/datasources")
  resp = conn["http"].request_get(path, conn["headers"])

  return JSON.parse(resp.read_body) if resp.is_a?(Net::HTTPOK)

  log_message = "Could not retrieve list of Grafana data sources"
  _raise_error(resp, log_message, "list_data_sources()")
end

def find_data_source_by_name(name, data_sources)
  data_sources.each do |data_source|
    return data_source if data_source["name"] == name
  end

  nil
end

def send_datasource(conn, payload)
  method = "POST"
  path = ::File.join(conn["base_path"], "/api/datasources")

  if payload["id"]
    path = ::File.join(path, payload["id"].to_s)
    method = "PUT"
  end

  headers = { "Content-Type" => "application/json" }.merge(conn["headers"])

  resp = conn["http"].send_request(method, path, JSON.generate(payload), headers)

  return if resp.is_a?(Net::HTTPOK)

  log_message = "Could not update data source #{payload["name"]}"
  _raise_error(resp, log_message, "send_datasource()")
end

def datasource_diff?(api, resource)
  res = false
  resource.each_key do |k|
    if resource[k].is_a?(Hash)
      res = datasource_diff?(api[k], resource[k])
      break if res == true
    end

    unless api.key?(k) && (api[k] == resource[k])
      res = true
      break
    end
  end

  res
end

def _build_connection(new_resource)
  uri = URI(new_resource.grafana_url)

  # Need to require net/https so that Net::HTTP gets monkey-patched
  # to actually support SSL:
  require "net/https" if uri.scheme.start_with?("https")

  # Construct authentication headers
  auth_headers = Net::HTTP::Get.new(new_resource.grafana_url)
  auth_headers.basic_auth(new_resource.user_name, new_resource.password)
  headers = { "Authorization" => auth_headers["authorization"] }

  # Construct the http object
  http = Net::HTTP.new(uri.host, uri.port)

  http.use_ssl = true if uri.scheme.start_with?("https")
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE if new_resource.insecure

  {
    "base_path" => new_resource.grafana_url,
    "http" => http,
    "headers" => headers
  }
end

def _datasource_payload(new_resource)
  {
    "url" => new_resource.proxy_url,
    "access" => "direct",
    "isDefault" => new_resource.is_default,
    "withCredentials" => false,
    "jsonData" => {
      "useHorizonProxy" => true,
      "token" => "",
      "keystoneAuth" => false,
      "authMode" => "Horizon"
    },
    "name" => new_resource.name,
    "type" => "monasca-datasource"
  }
end

def _log_error(resp, msg)
  Chef::Log.error(msg)
  Chef::Log.error("Response Code: #{resp.code}") if resp
  Chef::Log.error("Response Message: #{resp.message}") if resp
end

def _raise_error(resp, msg, calling_function)
  _log_error(resp, msg)
  new_resource.updated_by_last_action(false)
  raise "#{msg} in provider function #{calling_function}"
end
