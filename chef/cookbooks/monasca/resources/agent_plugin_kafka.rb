#
# Copyright 2017 SUSE Linux GmbH
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

actions :create
default_action :create

attribute :built_by, kind_of: String, regex: /\A[-\w.]*\z/, required: true
attribute :name, kind_of: String, regex: /\A[-\w.]*\z/, required: true
attribute :kafka_connect_str, kind_of: String, required: true
attribute :consumer_groups, kind_of: Hash, required: true
attribute :per_partition, kind_of: [TrueClass, FalseClass], default: false
attribute :full_output, kind_of: [TrueClass, FalseClass], default: false

attr_accessor :exists
