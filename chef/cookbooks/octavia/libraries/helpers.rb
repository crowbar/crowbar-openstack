
# Copyright (c) 2019 SUSE Linux, GmbH.
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
#
module OctaviaHelper
  def self.db_connection(db_settings, node)
    db_host = db_settings[:connection][:host]
    db_user = node[:octavia][:database][:user]
    db_pass = node[:octavia][:database][:password]
    db_name = node[:octavia][:database][:name]

    #TODO: mysqsl.ca? octavia_db_connection: "mysql+pymysql://{{ mysql.octavia_user }}:{{ mysql.octavia_password | urlencode }}@{{ mysql.host }}/octavia{% if mysql.use_tls %}{{ mysql.ca }}{% endif %}"

    Chef::Log.info "YYYY db connection mysql+pymysql://#{db_user}:#{db_pass}@#{db_host}/#{db_name}?charset=utf8"
    "mysql+pymysql://#{db_user}:#{db_pass}@#{db_host}/#{db_name}?charset=utf8"
  end
end
