#
# Copyright 2019 SUSE Linux GmbH
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

module CassandraHelper
  def self.set_password(role, new_password, **options)
    execute_cmd = "ALTER ROLE #{role} WITH password='#{new_password}'"
    cmd = base_cmd(execute: execute_cmd, **options)
    MonascaHelper.call(cmd)
  end

  def self.create_role_with_login(role, new_password, **options)
    execute_cmd = "CREATE ROLE IF NOT EXISTS #{role}"
    execute_cmd << " WITH PASSWORD='#{new_password}' AND LOGIN = true"
    cmd = base_cmd(execute: execute_cmd, **options)
    MonascaHelper.call(cmd)
  end

  def self.grant_read_permissions(role, **options)
    execute_cmd = "GRANT SELECT on keyspace monasca to #{role}"
    cmd = base_cmd(execute: execute_cmd, **options)
    MonascaHelper.call(cmd)
  end

  def self.grant_write_permissions(role, **options)
    execute_cmd = "GRANT MODIFY on keyspace monasca to #{role}"
    cmd = base_cmd(execute: execute_cmd, **options)
    MonascaHelper.call(cmd)
  end

  private_class_method def self.base_cmd(**options)
    has_user = options.fetch(:user, false)
    has_password = options.fetch(:password, false)
    has_execute = options.fetch(:execute, false)
    has_host = options.fetch(:host, false)

    base_cmd = "/usr/bin/cqlsh"
    base_cmd << " --user #{options[:user]}" if has_user
    base_cmd << " --password #{options[:password]}" if has_password
    base_cmd << " --execute \"#{options[:execute]}\"" if has_execute
    base_cmd << " #{options[:host]}" if has_host
    base_cmd
  end
end
