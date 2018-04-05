#
# Copyright 2017, SUSE LINUX Products GmbH
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

#
# This is a subclass of ServiceObject providing some helpers methods.
# Barclamps that have roles using pacemaker clusters should subclass this.
#
# It also provides some helpers that ServiceObject will wrap.
#

class OpenstackServiceObject < PacemakerServiceObject
  def apply_role_pre_chef_call(old_role, role, all_nodes)
    Rails.logger.debug("#{@bc_name} apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    # save attributes into the databag
    save_config_to_databag(old_role, role)
    Rails.logger.debug("#{@bc_name} apply_role_pre_chef_call: leaving")
  end

  def apply_role_post_chef_call(old_role, role, all_nodes)
    Rails.logger.debug("#{@bc_name} apply_role_post_chef_call: entering")
    # do this in post, because we depend on values that are computed in the
    # cookbook
    save_config_to_databag(old_role, role)
    Rails.logger.debug("#{@bc_name} apply_role_post_chef_call: leaving")
  end

  def save_config_to_databag(old_role, role)
    Rails.logger.debug("#{@bc_name} save_config_to_databag: entering")
    if role.nil?
      config = nil
    else
      config = role.default_attributes[@bc_name]
    end

    instance = Crowbar::DataBagConfig.instance_from_role(old_role, role)
    Crowbar::DataBagConfig.save("openstack", instance, @bc_name, config)
    Rails.logger.debug("#{@bc_name} save_config_to_databag: leaving")
  end
end
