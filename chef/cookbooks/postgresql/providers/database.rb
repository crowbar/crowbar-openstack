#
# Cookbook Name:: postgresql
# Provider:: database
#
# Copyright:: 2008-2011, Opscode, Inc <legal@opscode.com>
# Copyright:: 2012, SUSE <rhafer@suse.com>
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

include Opscode::Postgresql::Database

action :create_db do
  unless exists?
    begin
      Chef::Log.info "postgresql_database: Creating database #{new_resource.database}"
      db("template1").query("create database #{new_resource.database}")
      new_resource.updated_by_last_action(true)
    ensure
      db.close
    end
  end
end

action :query do
  if exists?
    begin
      Chef::Log.info "postgresql_database: Performing Query: #{new_resource.sql}"
      db("template1").query(new_resource.sql)
      new_resource.updated_by_last_action(true)
    ensure
      db.close
    end
  end
end

def load_current_resource
  Gem.clear_paths
  require 'pg'

  @postgresqldb = Chef::Resource::PostgresqlDatabase.new(new_resource.name)
  @postgresqldb.database(new_resource.database)
end

private
def exists?
  result = db("template1").exec(
              "SELECT datname FROM pg_database WHERE datname='#{new_resource.database}'"
           )
  result.num_tuples > 0
end
