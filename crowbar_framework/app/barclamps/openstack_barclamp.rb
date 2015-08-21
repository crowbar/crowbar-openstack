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

class OpenstackBarclamp < Crowbar::Registry::Barclamp
  name "openstack"
  display "OpenStack"
  description "Self-referential barclamp enabling other barclamps"

  member [
    "openstack"
  ]

  requires [
    "@crowbar",
    "horizon",
    "keystone"
  ]

  listed false

  layout 1
  version 0
  schema 3

  order 200

  nav(
    barclamps: {
      openstack: {
        order: 30,
        route: "index_barclamp_path",
        params: {
          controller: "openstack"
        }
      }
    },
    help: {
      crowbar_deployment: {
        order: 30,
        path: "/docs/crowbar_deployment_guide.pdf",
        html: {
          target: "_blank"
        }
      },
      openstack_users: {
        order: 40,
        path: "/docs/openstack_users_guide.pdf",
        html: {
          target: "_blank"
        }
      }
    }
  )
end
