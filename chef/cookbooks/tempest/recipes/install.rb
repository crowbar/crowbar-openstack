#
# Cookbook Name:: tempest
# Recipe:: install
#
# Copyright 2011, Dell, Inc.
# Copyright 2012, Dell, Inc.
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

if node[:platform_family] == "suse"
  #needed for tempest.tests.test_wrappers.TestWrappers.test_pretty_tox
  package "git-core"
else
  #needed for tempest.tests.test_wrappers.TestWrappers.test_pretty_tox
  package "git"
end

#needed for ec2 and s3 test suite
package "euca2ools"

package "openstack-tempest-test"

%w(keystone swift glance cinder neutron nova heat ceilometer).each do |component|
  package "python-#{component}client"
end
