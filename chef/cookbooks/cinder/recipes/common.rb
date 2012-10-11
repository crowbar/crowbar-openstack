# Copyright 2012 Dell, Inc.
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
# Cookbook Name:: cinder
# Recipe:: common
#

cinder_path = "/opt/cinder"

pfs_and_install_deps("cinder") do
  path cinder_path
end

create_user_and_dirs "cinder" do
end

execute "cp_policy.json" do
  command "cp #{cinder_path}/etc/cinder/policy.json /etc/cinder/"
  creates "/etc/cinder/policy.json"
end

template "/etc/sudoers.d/cinder-rootwrap" do
  source "cinder-rootwrap.erb"
  mode 0440
  variables(:user => node[:cinder][:user])
end

bash "deploy_filters" do
  cwd cinder_path
  code <<-EOH
  ### that was copied from devstack's stack.sh
  if [[ -d $CINDER_DIR/etc/cinder/rootwrap.d ]]; then
      # Wipe any existing rootwrap.d files first
      if [[ -d $CINDER_CONF_DIR/rootwrap.d ]]; then
          sudo rm -rf $CINDER_CONF_DIR/rootwrap.d
      fi
      # Deploy filters to /etc/cinder/rootwrap.d
      sudo mkdir -m 755 $CINDER_CONF_DIR/rootwrap.d
      sudo cp $CINDER_DIR/etc/cinder/rootwrap.d/*.filters $CINDER_CONF_DIR/rootwrap.d
      sudo chown -R root:root $CINDER_CONF_DIR/rootwrap.d
      sudo chmod 644 $CINDER_CONF_DIR/rootwrap.d/*
      # Set up rootwrap.conf, pointing to /etc/cinder/rootwrap.d
      sudo cp $CINDER_DIR/etc/cinder/rootwrap.conf $CINDER_CONF_DIR/
      sudo sed -e "s:^filters_path=.*$:filters_path=$CINDER_CONF_DIR/rootwrap.d:" -i $CINDER_CONF_DIR/rootwrap.conf
      sudo chown root:root $CINDER_CONF_DIR/rootwrap.conf
      sudo chmod 0644 $CINDER_CONF_DIR/rootwrap.conf
  fi
  ### end
  EOH
  environment({
    'CINDER_DIR' => cinder_path,
    'CINDER_CONF_DIR' => '/etc/cinder',
  })
  not_if {File.exists?("/etc/cinder/rootwrap.d")}
end

