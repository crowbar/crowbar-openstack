#
# Copyright 2016, SUSE
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

module Openstack
  class DataBagConfig
    class << self
      def insecure(barclamp, role)
        attributes = role.default_attributes[barclamp]

        use_ssl = if attributes.key?("api") && attributes["api"].key?("protocol")
          # aodh, cinder, glance, heat, keystone, manila, neutron
          attributes["api"]["protocol"] == "https"
        elsif attributes.key?("api") && attributes["api"].key?("ssl")
          # barbican
          attributes["api"]["ssl"]
        elsif attributes.key?("ssl") && attributes["ssl"].key?("enabled")
          # nova
          attributes["ssl"]["enabled"]
        else
          # ceilometer, magnum, sahara, trove
          false
        end

        insecure = use_ssl && attributes["ssl"]["insecure"]
        unless barclamp == "keystone"
          insecure ||= keystone_insecure(barclamp, role)
        end

        insecure
      end

      private

      def keystone_insecure(barclamp, role)
        keystone_config = Crowbar::DataBagConfig.load(
          "openstack",
          role.default_attributes[barclamp]["keystone_instance"],
          "keystone"
        )
        keystone_config["insecure"]
      end
    end
  end
end
