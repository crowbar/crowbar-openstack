#
# Cookbook Name:: keystone
# Provider:: register
#
# Copyright:: 2008-2011, Opscode, Inc <legal@opscode.com>
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

action :wakeup do
  http, headers = _build_connection(new_resource)

  # Lets verify that the service does not exist yet
  count = 0
  error = true
  while error and count < 50 do
    count = count + 1
    _, error = _get_service_id(http, headers, "fred")
    sleep 1 if error
  end

  raise "Failed to validate keystone is wake" if error

  new_resource.updated_by_last_action(true)
end

action :add_service do
  http, headers = _build_connection(new_resource)

  # Lets verify that the service does not exist yet
  item_id, error = _get_service_id(http, headers, new_resource.service_name)
  unless item_id or error
    # Service does not exist yet
    body = _build_service_object(new_resource.service_name,
                                 new_resource.service_type,
                                 new_resource.service_description)
    path = "/v3/services"
    ret = _create_item(http, headers, path, body, new_resource.service_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_service" if error
    Chef::Log.info "Service '#{new_resource.service_name}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

# :add_project specific attributes
# attribute :project_name, :kind_of => String
action :add_project do
  http, headers = _build_connection(new_resource)
  # Lets verify that the service does not exist yet
  item_id, error = _get_project_id(http, headers, new_resource.project_name)
  unless item_id or error
    # Service does not exist yet
    body = _build_project_object(new_resource.project_name)
    ret = _create_item(http, headers, "/v3/projects", body, new_resource.project_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_project" if error
    msg = "Project '#{new_resource.project_name}' already exists. Not creating."
    Chef::Log.info msg unless error
    new_resource.updated_by_last_action(false)
  end
end

# :add_domain specific attributes
# attribute :tenant_name, :kind_of => String
action :add_domain do
  http, headers = _build_connection(new_resource)

  # Construct the path
  path = "/v3/domains"
  dir = "domains"

  # Lets verify that the domain does not exist yet
  item_id, error = _find_id(http, headers, new_resource.domain_name, path, dir)
  if item_id || error
    raise "Failed to talk to keystone in add_domain" if error
    Chef::Log.info "Domain '#{new_resource.domain_name}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  else
    # Domain does not exist yet
    body = _build_domain_object(new_resource.domain_name)
    ret = _create_item(http, headers, path, body, new_resource.domain_name)
    new_resource.updated_by_last_action(ret)
  end
end

# :add_domain_role specific attributes
# attribute :domain_name, :kind_of => String
# attribute :user_name, :kind_of => String
# attribute :role_name, :kind_of => String
action :add_domain_role do
  http, headers = _build_connection(new_resource)

  user_id, user_error = _get_user_id(http, headers, new_resource.user_name)
  role_id, role_error = _get_role_id(http, headers, new_resource.role_name)
  # get domain_id
  path = "/v3/domains"
  dir = "domains"
  domain_id, derror = _find_id(http, headers, new_resource.domain_name, path, dir)

  if user_error || role_error || derror
    Chef::Log.info "Could not obtain the proper ids from keystone"
    raise "Failed to talk to keystone in add_domain_role"
  end

  # Construct the path
  path = "/v3/domains/#{domain_id}/users/#{user_id}/roles/#{role_id}"

  ret = _update_item(http, headers, path, nil, new_resource.domain_name)
  new_resource.updated_by_last_action(ret)
end

# :add_user specific attributes
# attribute :user_name, :kind_of => String
# attribute :user_password, :kind_of => String
# attribute :project_name, :kind_of => String
action :add_user do
  http, headers = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  project = new_resource.project_name
  project_id, project_error = _get_project_id(http, headers, project)

  # Lets verify that the service does not exist yet
  item_id, user_error = _get_user_id(http, headers, new_resource.user_name)

  raise "Failed to talk to keystone in add_user" if user_error || project_error

  ret = false
  body = _build_user_object(new_resource.user_name, new_resource.user_password, project_id)
  unless item_id
    # User does not exist yet
    path = "/v3/users"
    ret = _create_item(http, headers, path, body, new_resource.user_name)
  else
    auth_token = _get_token(http,
                            new_resource.user_name,
                            new_resource.user_password)
    if auth_token
      Chef::Log.debug "User '#{new_resource.user_name}' already exists and password still works."
      headers["X-Subject-Token"] = auth_token
      http.delete("/v3/auth/tokens", headers)
    else
      Chef::Log.debug "User '#{new_resource.user_name}' already exists. Updating Password."
      path = "/v3/users/#{item_id}"
      resp = http.send_request("PATCH", path, JSON.generate(body), headers)
      if resp.is_a?(Net::HTTPOK)
        Chef::Log.info("Updated keystone item '#{name}'")
      else
        _raise_error(respo, "Unable to update item '#{name}'", "add_user")
      end
    end
  end
  new_resource.updated_by_last_action(ret)
end

# :add_role specific attributes
# attribute :role_name, :kind_of => String
action :add_role do
  http, headers = _build_connection(new_resource)

  # Lets verify that the service does not exist yet
  item_id, error = _get_role_id(http, headers, new_resource.role_name)
  unless item_id or error
    # Service does not exist yet
    body = _build_role_object(new_resource.role_name)
    ret = _create_item(http, headers, "/v3/roles", body, new_resource.role_name)
    new_resource.updated_by_last_action(ret)
  else
    raise "Failed to talk to keystone in add_role" if error
    Chef::Log.info "Role '#{new_resource.role_name}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  end
end

# :add_access specific attributes
# attribute :project_name, :kind_of => String
# attribute :user_name, :kind_of => String
# attribute :role_name, :kind_of => String
action :add_access do
  http, headers = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  project = new_resource.project_name
  user = new_resource.user_name
  role = new_resource.role_name
  user_id, user_error = _get_user_id(http, headers, user)
  project_id, project_error = _get_project_id(http, headers, project)
  role_id, role_error = _get_role_id(http, headers, role)

  path = "/v3/projects/#{project_id}/users/#{user_id}/roles"
  assigned_role_id, assignment_error = _find_id(http, headers, role, path, "roles")
  Chef::Log.info("found role id: #{assigned_role_id}, error: #{assignment_error}")

  error = (assignment_error || role_error || user_error || project_error)
  if role_id == assigned_role_id || error
    raise "Failed to talk to keystone in add_access" if error
    msg = "Access '#{project}:#{user} -> #{role}' already exists. Not creating."
    Chef::Log.info msg unless error
    new_resource.updated_by_last_action(false)
  else
    # Role is not assigned yet
    ret = _update_item(http, headers, "#{path}/#{role_id}", nil, new_resource.role_name)
    new_resource.updated_by_last_action(ret)
  end
end

# :add_ec2 specific attributes
# attribute :user_name, :kind_of => String
# attribute :project_name, :kind_of => String
action :add_ec2 do
  http, headers = _build_connection(new_resource)

  # Lets verify that the item does not exist yet
  project = new_resource.project_name
  user = new_resource.user_name
  user_id, user_error = _get_user_id(http, headers, user)
  project_id, project_error = _get_project_id(http, headers, project)

  path = "/v3/users/#{user_id}/credentials/OS-EC2"
  matching_project_id, aerror = _find_id(http,
                                         headers,
                                         project_id,
                                         path,
                                         "credentials",
                                         "tenant_id",
                                         "tenant_id")

  error = (aerror || user_error || project_error)
  if project_id == matching_project_id || error
    raise "Failed to talk to keystone in add_ec2_creds" if error
    Chef::Log.info "EC2 '#{project}:#{user}' already exists. Not creating." unless error
    new_resource.updated_by_last_action(false)
  else
    # Service does not exist yet
    body = _build_ec2_object(project_id)
    ret = _create_item(http, headers, path, body, project)
    new_resource.updated_by_last_action(ret)
  end
end

action :add_endpoint do
  http, headers = _build_connection(new_resource)

  my_service_id, _error = _get_service_id(http, headers, new_resource.endpoint_service)
  unless my_service_id
    log_message = "Couldn't find service #{new_resource.endpoint_service} in keystone"
    _raise_error(nil, log_message, "add_endpoint")
  end

  # Construct the path
  path = "/v3/endpoints"

  # Lets verify that the endpoint does not exist yet
  resp = http.request_get(path, headers)
  unless resp.is_a?(Net::HTTPOK)
    log_message = "Unknown response from keystone server"
    _raise_error(resp, log_message, "add_endpoint")
  end

  data = JSON.parse(resp.read_body)
  endpoints = {}
  data["endpoints"].each do |endpoint|
    if endpoint["service_id"].to_s == my_service_id.to_s
      endpoints[endpoint["interface"]] = endpoint
    end
  end
  endpoint_updated = false
  ["public", "internal", "admin"].each do |interface|
    body = _build_endpoint_object(interface, my_service_id, new_resource)
    name = "#{interface} endpoint for '#{new_resource.endpoint_service}'"
    path = "/v3/endpoints"
    if endpoints.empty?
      _create_item(http, headers, path, body, name)
      endpoint_updated = true
    elsif endpoint_needs_update interface, endpoints, new_resource
      resp = http.send_request("PATCH",
                               "#{path}/#{endpoints[interface]["id"]}",
                               JSON.generate(body), headers)
      if resp.is_a?(Net::HTTPOK)
        msg = "Updated #{interface} keystone endpoint for '#{new_resource.endpoint_service}'"
        Chef::Log.info(msg)
        endpoint_updated = true
      else
        msg = "Unable to update #{interface} endpoint for '#{new_resource.endpoint_service}'"
        _raise_error(resp, msg, "add_endpoint")
      end
    end
  end
  if endpoint_updated
    new_resource.updated_by_last_action(true)
  else
    msg = "Keystone endpoints for '#{new_resource.endpoint_service}' already exist - not creating"
    Chef::Log.info(msg)
    new_resource.updated_by_last_action(false)
  end
end

action :update_endpoint do
  http, headers = _build_connection(new_resource)

  my_service_id, _error = _get_service_id(http, headers, new_resource.endpoint_service)
  unless my_service_id
    msg = "Couldn't find service #{new_resource.endpoint_service} in keystone"
    _raise_error(nil, msg, "update_endpoint")
  end

  path = "/v3/endpoints"

  resp = http.request_get(path, headers)
  if resp.is_a?(Net::HTTPOK)
    data = JSON.parse(resp.read_body)
    endpoints = {}
    data["endpoints"].each do |endpoint|
      if endpoint["service_id"].to_s == my_service_id.to_s
        endpoints[endpoint["interface"]] = endpoint
      end
    end
    ["public", "internal", "admin"].each do |interface|
      if interface == "public"
        new_url = new_resource.endpoint_publicURL
      elsif interface == "internal"
        new_url = new_resource.endpoint_internalURL
      elsif interface == "admin"
        new_url = new_resource.endpoint_adminURL
      end
      endpoint_template = {}
      endpoint_template["endpoint"] = {}
      endpoint_template["endpoint"]["interface"] = interface
      endpoint_template["endpoint"]["url"] = new_url
      endpoint_template["endpoint"]["endpoint_id"] = endpoints[interface]["id"]
      endpoint_template["endpoint"]["service_id"] = endpoints[interface]["service_id"]
      resp = http.send_request("PATCH",
                               "#{path}/#{endpoints[interface]["id"]}",
                               JSON.generate(endpoint_template), headers)
      if resp.is_a?(Net::HTTPOK)
        Chef::Log.info("Successfully updated endpoint URL #{interface} #{new_url}")
      else
        log_message = "Unknown response from keystone server"
        _raise_error(resp, log_message, "update_endpoint")
      end
    end
  else
    log_message = "Unknown response from keystone server"
    _raise_error(resp, log_message, "add_endpoint")
  end
end

# Return true on success
def _create_item(http, headers, path, body, name)
  resp = http.send_request("POST", path, JSON.generate(body), headers)
  if resp.is_a?(Net::HTTPCreated)
    Chef::Log.info("Created keystone item '#{name}'")
    return true
  elsif resp.is_a?(Net::HTTPOK)
    Chef::Log.info("Updated keystone item '#{name}'")
    return true
  else
    log_message = "Unable to create item '#{name}'"
    _raise_error(resp, log_message, "_create_item")
  end
end

# Return true on success
def _update_item(http, headers, path, body, name)
  unless body.nil?
    resp = http.send_request("PUT", path, JSON.generate(body), headers)
  else
    resp = http.send_request("PUT", path, nil, headers)
  end
  if resp.is_a?(Net::HTTPOK)
    Chef::Log.info("Updated keystone item '#{name}'")
    return true
  elsif resp.is_a?(Net::HTTPCreated)
    Chef::Log.info("Created keystone item '#{name}'")
    return true
  # several APIs use 204 on v3 as success response
  elsif resp.is_a?(Net::HTTPNoContent)
    Chef::Log.info("Created/Updated keystone item #{name}")
    return true
  else
    log_message = "Unable to update item '#{name}'"
    _raise_error(resp, log_message, "_update_item")
  end
end

private
def _build_connection(new_resource)
  # Need to require net/https so that Net::HTTP gets monkey-patched
  # to actually support SSL:
  require "net/https" if new_resource.protocol == "https"

  # Construct the http object
  http = Net::HTTP.new(new_resource.host, new_resource.port)
  http.use_ssl = true if new_resource.protocol == "https"
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE if new_resource.insecure

  auth_token = nil
  if new_resource.token
    auth_token = new_resource.token
  elsif new_resource.auth
    auth_token = _get_token(http,
                            new_resource.auth[:user],
                            new_resource.auth[:password],
                            new_resource.auth[:tenant])
    unless auth_token
      raise "Authentication failed for user #{new_resource.auth[:user]}"
    end
  else
    raise "Neither token nor auth parameter present. Failed to authenticate"
  end

  # Fill out the headers
  headers = _build_headers(auth_token)

  [http, headers]
end

def _find_id(http, headers, item_name, path, dir, key = "name", ret = "id")
  # Construct the path
  my_item_id = nil
  error = false
  resp = http.request_get(path, headers)
  if resp.is_a?(Net::HTTPOK)
    data = JSON.parse(resp.read_body)
    data = data[dir]

    data.each do |item|
      my_item_id = item[ret] if item[key] == item_name
      break if my_item_id
    end
  else
    log_message = "Find #{path}: #{item_name}: Unknown response from Keystone Server"
    _log_error(resp, log_message)
    error = true
  end
  [my_item_id, error]
end

def _build_service_object(svc_name, svc_type, svc_desc)
  body = {
    service: {
      name: svc_name,
      type: svc_type,
      description: svc_desc
    }
  }
  body
end

def _build_user_object(user_name, password, project_id, domain_id = "default")
  body = {
    user: {
      name: user_name,
      password: password,
      default_project_id: project_id,
      domain_id: domain_id,
      enabled: true
    }
  }
  body
end

def _build_auth(user_name,
                password,
                project = "",
                user_domain = "Default",
                project_domain = "Default")
  body = {
    auth: {
      identity: {
        methods: ["password"],
        password: {
          user: {
            name: user_name,
            password: password,
            domain: {
              name: user_domain
            }
          }
        }
      }
    }
  }
  unless project.empty? || project.nil?
    scope = {
      project: {
        name: project,
        domain: {
          name: project_domain
        }
      }
    }
    body[:auth][:scope] = scope
  end
  body
end

def _get_token(http, user_name, password, project = "")
  path = "/v3/auth/tokens"
  headers = _build_headers
  body = _build_auth(user_name, password, project)
  resp = http.send_request("POST", path, JSON.generate(body), headers)
  if resp.is_a?(Net::HTTPCreated) || resp.is_a?(Net::HTTPOK)
    resp["X-Subject-Token"]
  else
    msg = "Failed to get token for User '#{user_name}'"
    msg += " Project '#{project}'" unless project.empty?
    Chef::Log.info msg
    Chef::Log.info "Response Code: #{resp.code}"
    Chef::Log.info "Response Message: #{resp.message}"
    nil
  end
end

def _build_role_object(role_name)
  body = {
    role: {
      name: role_name
    }
  }
  body
end

def _build_project_object(project_name, domain_id = "default")
  body = {
    project: {
      name: project_name,
      enabled: true,
      domain_id: domain_id
    }
  }
  body
end

def _build_domain_object(domain_name)
  body = {
    domain: {
      name: domain_name,
      enabled: true
    }
  }
  body
end

def _build_access_object(role_id, role_name)
  svc_obj = Hash.new
  svc_obj.store("name", role_name)
  svc_obj.store("id", role_id)
  ret = Hash.new
  ret.store("role", svc_obj)
  return ret
end

def _build_ec2_object(project_id)
  body = {
    tenant_id: project_id
  }
  body
end

def _build_endpoint_object(interface, service, new_resource)
  new_url = new_resource.send("endpoint_#{interface}URL".to_sym)
  body = {
    endpoint: {
      service_id: service,
      region: new_resource.endpoint_region,
      url: new_url,
      interface: interface,
      enabled: new_resource.endpoint_enabled
    }
  }
  body
end

private
def _build_headers(token = nil)
  ret = Hash.new
  ret.store("X-Auth-Token", token) if token
  ret.store("Content-type", "application/json")
  return ret
end

def endpoint_needs_update(interface, endpoints, new_resource)
  !(endpoints[interface]["url"] == new_resource.send("endpoint_#{interface}URL") &&
      endpoints[interface]["region_id"] == new_resource.endpoint_region)
end

def _get_service_id(http, headers, svc_name)
  _find_id(http, headers, svc_name, "/v3/services", "services")
end

def _get_project_id(http, headers, project_name)
  _find_id(http, headers, project_name, "/v3/projects", "projects")
end

def _get_user_id(http, headers, user_name)
  _find_id(http, headers, user_name, "/v3/users", "users")
end

def _get_role_id(http, headers, role_name)
  _find_id(http, headers, role_name, "/v3/roles", "roles")
end

def _log_error(resp, msg)
  Chef::Log.error(msg)
  Chef::Log.error("Response Code: #{resp.code}") if resp
  Chef::Log.error("Response Message: #{resp.message}") if resp
end

def _raise_error(resp, msg, calling_action)
  _log_error(resp, msg)
  new_resource.updated_by_last_action(false)
  raise "#{msg} in #{calling_action}"
end
