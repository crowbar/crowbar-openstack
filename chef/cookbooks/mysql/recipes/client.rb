#
# Cookbook Name:: mysql
# Recipe:: client
#
# Copyright 2008-2011, Opscode, Inc.
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

package node[:mysql][:mysql_client]

if platform_family?(%w{debian rhel fedora suse})

  package "mysql-ruby" do
    package_name value_for_platform_family(
      ["rhel", "fedora"] => "ruby-mysql",
      "suse" => "ruby#{node["languages"]["ruby"]["version"].to_f}-rubygem-mysql2",
      "default" => "libmysql-ruby"
    )
    action :install
  end

else

  gem_package "mysql" do
    action :install
  end

end
