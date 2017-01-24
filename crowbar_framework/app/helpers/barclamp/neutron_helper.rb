#
# Copyright 2011-2013, Dell
# Copyright 2013-2015, SUSE LINUX Products GmbH
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

module Barclamp
  module NeutronHelper

    def networking_plugins_for_neutron(selected)
      options_for_select(
        NeutronService.networking_plugins_valid.map { |el| [el, el] },
        selected.to_s
      )
    end

    def options_keep_order(valid_options, selected)
      # preserve the order of the selected entries
      options = []
      selected.each do |el|
        if valid_options.include?(el)
          options << [el, el]
          valid_options.delete(el)
        end
      end
      # append unselected but valid options
      valid_options.each do |el|
        options << [el, el]
      end
      options
    end

    def networking_ml2_mechanism_drivers_for_neutron(selected)
      selected = selected.gsub(/\s+/, "").split(",")
      valid_options = NeutronService.networking_ml2_mechanism_drivers_valid
      options_for_select(options_keep_order(valid_options, selected), selected)
    end

    def networking_ml2_type_drivers_for_neutron(selected)
      selected = selected.gsub(/\s+/, "").split(",")
      valid_options = NeutronService.networking_ml2_type_drivers_valid
      options_for_select(options_keep_order(valid_options, selected), selected)
    end

    def networking_ml2_type_drivers_default_provider_network_for_neutron(selected)
      options_for_select(NeutronService.networking_ml2_type_drivers_valid.map { |x| [x, x] },
                         selected.to_s)
    end

    def networking_ml2_type_drivers_default_tenant_network_for_neutron(selected)
      options_for_select(NeutronService.networking_ml2_type_drivers_valid.map { |x| [x, x] },
                         selected.to_s)
    end

    def networking_lbaasv2_drivers(selected)
      options_for_select(
        [
          ["HAProxy", "haproxy"],
          ["F5", "f5"]
        ],
        selected.to_s
      )
    end

    def f5_ha_type(selected)
      options_for_select(
        [
          [t(".f5.ha_types.standalone"), "standalone"],
          [t(".f5.ha_types.pair"), "pair"],
          [t(".f5.ha_types.scalen"), "scalen"]
        ],
        selected.to_s
      )
    end

    def api_protocols_for_neutron(selected)
      options_for_select(
        [
          ["HTTP", "http"],
          ["HTTPS", "https"]
        ],
        selected.to_s
      )
    end
  end
end
