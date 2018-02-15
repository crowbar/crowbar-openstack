#
# Copyright 2011-2013, Dell
# Copyright 2013-2014, SUSE LINUX Products GmbH
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
  module RabbitmqHelper
    def ha_storage_mode_for_rabbitmq(selected)
      options_for_select(
        [
          [t(".ha.storage.modes.drbd"), "drbd"],
          [t(".ha.storage.modes.shared"), "shared"]
        ],
        selected.to_s
      )
    end

    def log_levels_for_rabbitmq(selected)
      options_for_select(
        [
          ["debug", "debug"],
          ["info", "info"],
          ["warning", "warning"],
          ["error", "error"],
          ["critical", "critical"],
          ["none", "none"]
        ],
        selected.to_s
      )
    end
  end
end
