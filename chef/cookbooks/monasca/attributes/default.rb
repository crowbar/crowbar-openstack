#
# Copyright 2016 SUSE Linux GmbH
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
# limitation.

default[:monasca][:db][:database] = "monasca"
default[:monasca][:db][:user] = "monasca"
default[:monasca][:db][:password] = nil # must be set by wrapper

override[:monasca][:group] = "monasca"
override[:monasca][:user] = "monasca"

default[:monasca][:debug] = false
default[:monasca][:ha_enabled] = false

default[:monasca][:api][:bind_host] = "*"
