#
# Copyright 2017 FUJITSU LIMITED
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
  module MonascaHelper
    def agent_log_levels(selected)
      options_for_select(
        [
          ["Error", "ERROR"],
          ["Warning", "WARNING"],
          ["Info", "INFO"],
          ["Debug", "DEBUG"]
        ],
        selected.to_s
      )
    end

    def api_log_levels(selected)
      options_for_select(
        [
          ["Critical", "CRITICAL"],
          ["Error", "ERROR"],
          ["Warning", "WARNING"],
          ["Info", "INFO"],
          ["Debug", "DEBUG"],
          ["Trace", "TRACE"]
        ],
        selected.to_s
      )
    end
  end
end
