#
# Copyright 2011-2013, Dell
# Copyright 2013-2015, SUSE Linux GmbH
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

class HeatBarclamp < Crowbar::Registry::Barclamp
  name "heat"
  display "Heat"
  description "OpenStack Orchestration: Orchestration engine for composite cloud applications"

  member [
    "openstack"
  ]

  requires [
    "@crowbar",
    "pacemaker",
    "git",
    "database",
    "rabbitmq",
    "keystone",
    "neutron",
    "cinder",
    "glance",
    "nova"
  ]

  listed true

  layout 1
  version 0
  schema 3

  order 97
end
