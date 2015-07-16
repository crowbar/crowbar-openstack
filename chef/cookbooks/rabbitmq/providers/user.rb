#
# Cookbook Name:: rabbitmq
# Provider:: user
#
# Copyright 2011, Opscode, Inc.
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

action :add do
  unless Kernel::system("rabbitmqctl list_users | grep -q #{new_resource.user}")
    Chef::Log.info "Adding RabbitMQ user '#{new_resource.user}'."
    execute "rabbitmqctl add_user #{new_resource.user} #{new_resource.password}"
    new_resource.updated_by_last_action(true)
  else
    unless new_resource.address.nil? or new_resource.port.nil?
      unless _can_connect(new_resource.address, new_resource.port, new_resource.user, new_resource.password)
        Chef::Log.info "Updating password for RabbitMQ user '#{new_resource.user}'."
        execute "rabbitmqctl change_password #{new_resource.user} #{new_resource.password}"
        new_resource.updated_by_last_action(true)
      end
    end
  end
end

action :delete do
  if Kernel::system("rabbitmqctl list_users | grep -q #{new_resource.user}")
    Chef::Log.info "Deleting RabbitMQ user '#{new_resource.user}'."
    execute "rabbitmqctl delete_user #{new_resource.user}"
    new_resource.updated_by_last_action(true)
  end
end

action :set_permissions do
  unless Kernel::system("test `rabbitmqctl list_user_permissions #{new_resource.user} | wc -l` -gt 2")
    if new_resource.vhost
      Chef::Log.info "Setting RabbitMQ user permissions for '#{new_resource.user}' on vhost #{new_resource.vhost}."
      execute "rabbitmqctl set_permissions -p #{new_resource.vhost} #{new_resource.user} #{new_resource.permissions}"
    else
      Chef::Log.info "Setting RabbitMQ user permissions for '#{new_resource.user}'."
      execute "rabbitmqctl set_permissions #{new_resource.user} #{new_resource.permissions}"
    end
    new_resource.updated_by_last_action(true)
  end
end

action :clear_permissions do
  if Kernel::system("rabbitmqctl list_user_permissions #{new_resource.user} | grep -q #{new_resource.user}")
    if new_resource.vhost
      Chef::Log.info "Clearing RabbitMQ user permissions for '#{new_resource.user}' from vhost #{new_resource.vhost}."
      execute "rabbitmqctl clear_permissions -p #{new_resource.vhost} #{new_resource.user}"
    else
      Chef::Log.info "Clearing RabbitMQ user permissions for '#{new_resource.user}'."
      execute "rabbitmqctl clear_permissions #{new_resource.user}"
    end
    new_resource.updated_by_last_action(true)
  end
end

private
def _can_connect(address, port, user, password)
  http = Net::HTTP.new(address, port)
  request = Net::HTTP::Get.new('/api/whoami')
  request.basic_auth(user, password)
  resp, data = http.request(request)
  # if we get something different than OK and Unauthorized, then we don't know
  # what's going on, so we'll assume it's like OK
  return (not resp.is_a?(Net::HTTPUnauthorized))
end
