# Copyright 2015, SUSE, Inc.
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

default[:sahara][:debug] = false

override[:sahara][:user] = "sahara"
override[:sahara][:group] = "sahara"

default[:sahara][:max_header_line] = 16384

default[:sahara][:api][:protocol] = "http"

default[:sahara][:ha][:enabled] = false
#TODO: HA attributes
