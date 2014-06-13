#
# Cookbook Name:: database
# Recipe:: crowbar
#
# Copyright 2014, SUSE Linux GmbH
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

# XXX hack since we can't modify attributes in the postgresql namespace
# in crowbar.
# Chef doesn't allow us to call merge/merge! directly on node attributes
node['postgresql'] = node['postgresql'].to_hash.merge(node['database']['postgresql'])
