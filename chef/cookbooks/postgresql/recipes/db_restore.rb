#
# Cookbook Name:: postgresql
# # Recipe:: db_restore
#
# Copyright 2013-2016, SUSE LINUX GmbH
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

service_name = "postgresql"
dump_location = node[:crowbar][:upgrade][:db_dump_location]

if node[:database][:ha][:enabled]
  # Checks that the service is available, if it's running on this node.
  service_available = "crm resource show #{service_name} | " \
    "grep \" #{node.hostname} *$\" | grep -q 'running'"
  execute "restore database from #{dump_location}" do
    command "/usr/lib/postgresql94/bin/psql -d postgres -f #{dump_location}"
    user "postgres"
    only_if service_available
  end
else
  execute "restore database from #{dump_location}" do
    command "/usr/lib/postgresql94/bin/psql -d postgres -f #{dump_location}"
    user "postgres"
  end
end

# Creates file to indicate successful restore of database.
file "#{dump_location}.restored-ok" do
  action :create
end
