#
# Copyright 2016, SUSE
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

module NovaBootKernel
  def self.set_boot_kernel_and_trigger_reboot(node, flavor = "default")
    # only default and xen flavor is supported by this helper right now
    if node[:platform] == "suse" && node[:platform_version].to_f < 12.0
      set_boot_kernel_grub1(flavor)
    else
      set_boot_kernel_grub2(flavor)
    end

    # trigger reboot through reboot_handler, if kernel-$flavor is not yet
    # running
    unless Dir.exist?("/proc/xen") && flavor == "xen" ||
        !Dir.exist?("/proc/xen") && flavor == "default"
      if node["crowbar_upgrade_step"] == "done_os_upgrade"
        Chef::Log.info("Skipping reboot in the initial run after upgrade")
      else
        node.run_state[:reboot] = true
      end
    end
  end

  protected

  def self.set_boot_kernel_grub1(flavor = "default")
    default_boot = 0
    current_default = nil

    # parse grub config, to find boot index for selected flavor
    File.open("/boot/grub/menu.lst").each_line do |line|
      current_default = line.scan(/\d/).first.to_i if line.start_with?("default")

      next unless line.start_with?("title")

      if flavor.eql?("xen")
        # found boot index
        break if line.include?("Xen")
      else
        # take first non-xen kernel as default
        break unless line.include?("Xen")
      end
      default_boot += 1
    end

    # change default option for grub config
    unless current_default.eql?(default_boot)
      Chef::Log.info("changed grub default to #{default_boot}")
      `sed -i -e "s;^default.*;default #{default_boot};" /boot/grub/menu.lst`
    end
  end

  def self.set_boot_kernel_grub2(flavor = "default")
    default_boot = "SLES12"
    grub_env = `grub2-editenv list`
    if grub_env.include?("saved_entry")
      current_default = grub_env.strip.split("=")[1]
    else
      current_default = nil
    end

    # parse grub config, to find boot index for selected flavor
    File.open("/boot/grub2/grub.cfg").each_line do |line|
      next unless line.start_with?("menuentry")

      default_boot = line.sub(/^menuentry '([^']*)'.*$/, '\1').strip
      if flavor.eql?("xen")
        # found boot index
        break if line.include?("Xen")
      else
        # take first non-xen kernel as default
        break unless line.include?("Xen")
      end
    end

    # change default option for grub config
    unless current_default.eql?(default_boot)
      Chef::Log.info("changed grub default to #{default_boot}")
      `grub2-set-default '#{default_boot}'`
    end
  end
end
