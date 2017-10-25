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
# limitations under the License.
#

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  # NOTE(aplanas) @current_resource is not accesible inside the
  # coverge_by block for some reason
  current_resource = @current_resource

  converge_by("Create #{@new_resource}") do
    # Install the mod_wsgi package if needed and make some
    # preparations
    case node[:platform_family]
    when "debian"
      package "libapache2-mod-wsgi"
    when "rhel", "fedora", "arch"
      package "mod_wsgi"
    when "suse"
      package "apache2-mod_wsgi"
    end
    apache_module "wsgi"

    apache_site "000-default" do
      enable false
    end

    apache_module "ssl" if current_resource.ssl_enable

    template _get_vhost_name do
      source "vhost-wsgi.conf.erb"
      owner node[:apache][:user]
      group node[:apache][:group]
      mode "0644"
      cookbook "crowbar-openstack"
      variables(
        bind_host: current_resource.bind_host,
        bind_port: current_resource.bind_port,
        daemon_process: current_resource.daemon_process,
        user: current_resource.user,
        group: current_resource.group,
        processes: current_resource.processes,
        threads: current_resource.threads,
        process_group: current_resource.process_group,
        script_alias: current_resource.script_alias,
        directory: current_resource.directory,
        pass_authorization: current_resource.pass_authorization,
        limit_request_body: current_resource.limit_request_body,
        ssl_enable: current_resource.ssl_enable,
        ssl_certfile: current_resource.ssl_certfile,
        ssl_keyfile: current_resource.ssl_keyfile,
        ssl_cacert: current_resource.ssl_cacert,
        timeout: current_resource.timeout,
        access_log: current_resource.access_log,
        error_log: current_resource.error_log,
        apache_log_dir: node[:apache][:log_dir],
      )
      notifies :reload, resources(service: "apache2"), :delayed
    end
    Chef::Log.info "#{@new_resource} created / updated"
  end
end

action :delete do
  if @current_resource.exists
    converge_by("Delete #{@new_resource}") do
      file _get_vhost_name do
        action :delete
        only_if { File.exist?(_get_vhost_name) }
        notifies :reload, resources(service: "apache2"), :delayed
      end
      Chef::Log.info "#{@new_resource} deleted"
    end
  else
    Chef::Log.info "#{@current_resource} doesn't exist - can't delete."
  end
end

def load_current_resource
  @current_resource = Chef::Resource::CrowbarOpenstackWsgi.new(@new_resource.name)

  @current_resource.bind_host(@new_resource.bind_host)
  @current_resource.bind_port(@new_resource.bind_port)
  @current_resource.daemon_process(@new_resource.daemon_process)
  @current_resource.user(@new_resource.user)
  @current_resource.group(_get_group)
  @current_resource.processes(@new_resource.processes)
  @current_resource.threads(@new_resource.threads)
  @current_resource.process_group(_get_process_group)
  @current_resource.script_alias(_get_script_alias)
  @current_resource.directory(_get_directory)

  @current_resource.pass_authorization(@new_resource.pass_authorization)
  @current_resource.limit_request_body(@new_resource.limit_request_body)

  @current_resource.ssl_enable(@new_resource.ssl_enable)
  @current_resource.ssl_certfile(@new_resource.ssl_certfile)
  @current_resource.ssl_keyfile(@new_resource.ssl_keyfile)
  @current_resource.ssl_cacert(@new_resource.ssl_cacert)

  @current_resource.timeout(@new_resource.timeout)

  @current_resource.access_log(_get_access_log)
  @current_resource.error_log(_get_error_log)

  @current_resource.exists = true if ::File.exist?(_get_vhost_name)

  @current_resource
end

private

def _get_vhost_name
  apache_dir = node[:apache][:dir]
  "#{apache_dir}/vhosts.d/#{@new_resource.daemon_process}.conf"
end

def _get_group
  @new_resource.group || @new_resource.user
end

def _get_process_group
  @new_resource.process_group || @new_resource.daemon_process
end

def _get_script_alias
  default_script_alias = "/srv/www/#{@new_resource.daemon_process}/app.wsgi"
  @new_resource.script_alias || default_script_alias
end

def _get_directory
  default_directory = ::File.dirname(_get_script_alias)
  @new_resource.directory || default_directory
end

def _get_access_log
  default_log = "#{@new_resource.daemon_process}_access.log"
  @new_resource.access_log || default_log
end

def _get_error_log
  default_log = "#{@new_resource.daemon_process}_error.log"
  @new_resource.error_log || default_log
end
