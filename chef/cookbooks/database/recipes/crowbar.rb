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

def pg_hash_only_merge(merge_onto, merge_with)
  # If there are two Hashes, recursively merge.
  if merge_onto.kind_of?(Hash) && merge_with.kind_of?(Hash)
    merge_with.each do |key, merge_with_value|
      merge_onto[key] = pg_hash_only_merge(merge_onto[key], merge_with_value)
    end
    merge_onto

    # If merge_with is nil, don't replace merge_onto
  elsif merge_with.nil?
    merge_onto

    # In all other cases, replace merge_onto with merge_with
  else
    merge_with
  end
end

if Chef::VERSION.split('.')[0].to_i >= 11
  raise "Your chef version has hash_only_merge; consider removing the local copy."
else
  node.default['postgresql'] = pg_hash_only_merge(node.default['postgresql'].to_hash, node.default['database']['postgresql'].to_hash)
end

# stoney had a bug where we were merging all attributes (including default and
# override) as normal attributes, so fix it here
# Note that the postgresql.client key should never be in normal, so this means
# we'll do that only once.
if !node.normal_attrs['postgresql'].nil? && node.normal_attrs['postgresql'].has_key?('client')
  node.normal_attrs.delete(:postgresql)
  node.save
end
