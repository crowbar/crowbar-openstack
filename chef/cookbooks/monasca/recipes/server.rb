# Copyright 2016 SUSE Linux GmbH
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
# TODO: Fill this with code that deploys the Monasca backend services

### Example code for retrieving a database URL and keystone settings:

# keystone_settings = KeystoneHelper.keystone_settings(node, @cookbook_name),

# db_settings = fetch_database_settings
# db_conn_scheme = db_settings[:url_scheme]

# if db_settings[:backend_name] == "mysql"
#  db_conn_scheme = "mysql+pymysql"
# end

# database_connection = "#{db_conn_scheme}://" \
# "#{node[:monasca][:db][:user]}" \
# ":#{node[:monasca][:db][:password]}" \
#  "@#{db_settings[:address]}" \
#  "/#{node[:monasca][:db][:database]}"
