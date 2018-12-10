#
# Copyright (c) 2015 SUSE Linux GmbH.
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
# This is the second of a 2 part set of scripts to ensure that ceph support
# is added to nova/libvirt.  This first part ensures that the ceph config
# files and keyrings are in place.  The 2nd part is run after libvirtd has
# been installed and started, so the virsh secrets can be installed.

# Cookbook Name:: nova
# Recipe:: ceph
#

has_internal = false
has_external = false

cinder_controller = node_search_with_cache("roles:cinder-controller").first
return if cinder_controller.nil?

# First loop to find if we have internal/external cluster
cinder_controller[:cinder][:volumes].each_with_index do |volume, volid|
  next unless volume[:backend_driver] == "rbd"

  has_internal ||= true if volume[:rbd][:use_crowbar]
  has_external ||= true unless volume[:rbd][:use_crowbar]
end

# Second loop to do our setup
cinder_controller[:cinder][:volumes].each_with_index do |volume, volid|
  next unless volume[:backend_driver] == "rbd"

  rbd_user = volume[:rbd][:user]
  rbd_uuid = volume[:rbd][:secret_uuid]

  if volume[:rbd][:use_crowbar]
    ceph_conf = "/etc/ceph/ceph.conf"
    admin_keyring = "/etc/ceph/ceph.client.admin.keyring"
  else
    ceph_conf = volume[:rbd][:config_file]
    admin_keyring = volume[:rbd][:admin_keyring]

    if ceph_conf.empty? || !File.exist?(ceph_conf)
      Chef::Log.info("Ceph configuration file is missing; skipping the ceph setup for backend #{volume[:backend_name]}")
      next
    end

    if !admin_keyring.empty? && File.exist?(admin_keyring)
      cmd = ["ceph", "--id", rbd_user, "-c", ceph_conf, "-s"]
      Log::info("Check ceph -s with #{cmd}")
      check_ceph = Mixlib::ShellOut.new(cmd)

      unless check_ceph.run_command.stdout.match("(HEALTH_OK|HEALTH_WARN)")
        Chef::Log.info("Ceph cluster is not healthy; Nova skipping the ceph setup for backend #{volume[:backend_name]}")
        next
      end
    else
      # Check if rbd keyring was uploaded manually by user
      client_keyring = "/etc/ceph/ceph.client.#{rbd_user}.keyring"
      unless File.exist?(client_keyring)
        Chef::Log.info("Ceph user keyring wasn't provided for backend #{volume[:backend_name]}")
        next
      end
    end

  end

  ruby_block "save nova key as libvirt secret" do
    block do
      # Check if libvirt is installed and started
      if system("virsh hostname &> /dev/null")

        # First remove conflicting secrets due to same usage name
        virsh_secret = Mixlib::ShellOut.new("virsh secret-list")
        secret_list = virsh_secret.run_command.stdout
        virsh_secret.error!

        secret_lines = secret_list.strip.split("\n")
        if secret_lines.length < 2 || !secret_lines[0].lstrip.start_with?("UUID") || !secret_lines[1].start_with?("----")
          raise "cannot fetch list of libvirt secret"
        end
        secret_lines.shift(2)

        secret_lines.each do |secret_line|
          secret_uuid = secret_line.split(" ")[0]
          cmd = ["virsh", "secret-dumpxml", secret_uuid]
          virsh_secret_dumpxml = Mixlib::ShellOut.new(cmd)
          secret_xml = virsh_secret_dumpxml.run_command.stdout
          # some secrets might not be ceph-related, skip these
          next if secret_xml.index("<usage type='ceph'>").nil?

          # lazy xml parsing
          re_match = %r[<usage type='ceph'>.*<name>(.*)</name>]m.match(secret_xml)
          next if re_match.nil?
          secret_usage = re_match[1]
          undefine = false

          if secret_uuid == rbd_uuid
            undefine = true if secret_usage != "crowbar-#{rbd_uuid} secret"
          else
            undefine = true if secret_usage == "crowbar-#{rbd_uuid} secret"
          end

          if undefine
            Chef::Log.info("undefine existing secret for #{secret_uuid}")
            cmd = ["virsh", "secret-undefine", secret_uuid]
            virsh_secret_undefine = Mixlib::ShellOut.new(cmd)
            virsh_secret_undefine.run_command
          end
        end

        # Lets see if we have a SES barclamp keyring file
        # Check if rbd keyring was created by SES barclamp
        client_keyring = "/etc/ceph/ceph.client.#{rbd_user}.keyring"
        Chef::Log.info("Check to see if we have a #{client_keyring} file.")
        client_key = ''
        if File.exist?(client_keyring)
          f = File.open(client_keyring)
          f.each do |line|
            if match = line.match("key\s*=\s*(.+)")
              client_key = match[1]
              break
            end
          end
        else
          if !admin_keyring.empty? && File.exist?(admin_keyring)
            # Now add our secret and its value
            cmd = [
              "ceph",
              "-k", admin_keyring,
              "-c", ceph_conf,
              "auth",
              "get-or-create-key",
              "client.#{rbd_user}"
            ]

            ceph_get_key = Mixlib::ShellOut.new(cmd)
            client_key = ceph_get_key.run_command.stdout.strip
            ceph_get_key.error!
          end
        end

        cmd = ["virsh", "secret-get-value", rbd_uuid]
        virsh_secret_get_value = Mixlib::ShellOut.new(cmd)
        secret = virsh_secret_get_value.run_command.stdout.chomp.strip

        if secret != client_key
          secret_file_path = "/etc/ceph/ceph-secret-#{rbd_uuid}.xml"
          secret_file_content = "<secret ephemeral='no' private='no'>" \
                                " <uuid>#{rbd_uuid}</uuid>" \
                                " <usage type='ceph'>" \
                                " <name>crowbar-#{rbd_uuid} secret</name>" \
                                " </usage> " \
                                "</secret>"
          File.write(secret_file_path, secret_file_content)

          Chef::Log.info("Create new virsh secret #{rbd_uuid}")
          cmd = ["virsh", "secret-define", "--file", secret_file_path]
          virsh_secret_define = Mixlib::ShellOut.new(cmd)
          secret_uuid_out = virsh_secret_define.run_command.stdout

          if secret_uuid_out.scan(/(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})/)
            cmd = ["virsh", "secret-set-value", "--secret", rbd_uuid, "--base64", client_key]
            virsh_secret_set_value = Mixlib::ShellOut.new(cmd)
            virsh_secret_set_value.run_command
            virsh_secret_set_value.error!
          else
            raise "Libvirt secret for UUID #{rbd_uuid} was not created properly."
          end

          File.delete(secret_file_path)
        end
      else
        Chef::Log.info("Virsh isn't running, we can't install virsh secret.")
      end
    end
  end
end
