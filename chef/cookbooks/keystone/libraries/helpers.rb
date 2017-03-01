module KeystoneHelper
  def self.service_URL(protocol, host, port)
    "#{protocol}://#{host}:#{port}"
  end

  def self.versioned_service_URL(protocol, host, port, version)
    unless version.start_with?("v")
      version = "v#{version}"
    end
    service_URL(protocol, host, port) + "/" + version + "/"
  end

  def self.admin_auth_url(node, admin_host)
    service_URL(node[:keystone][:api][:protocol], admin_host, node[:keystone][:api][:admin_port])
  end

  def self.public_auth_url(node, public_host)
    versioned_service_URL(node[:keystone][:api][:protocol],
                          public_host,
                          node[:keystone][:api][:service_port],
                          node[:keystone][:api][:version])
  end

  def self.internal_auth_url(node, admin_host)
    versioned_service_URL(node[:keystone][:api][:protocol],
                          admin_host,
                          node[:keystone][:api][:service_port],
                          node[:keystone][:api][:version])
  end

  def self.unversioned_internal_auth_url(node, admin_host)
    service_URL(node[:keystone][:api][:protocol], admin_host, node[:keystone][:api][:service_port])
  end

  def self.keystone_settings(current_node, cookbook_name)
    instance = current_node[cookbook_name][:keystone_instance] || "default"

    # Cache the result for each cookbook in an instance variable hash. This
    # cache needs to be invalidated for each chef-client run from chef-client
    # daemon (which are all in the same process); so use the ohai time as a
    # marker for that.
    if @keystone_settings_cache_time != current_node[:ohai_time]
      if @keystone_settings
        Chef::Log.info("Invalidating keystone settings cache " \
                       "on behalf of #{cookbook_name}")
      end
      @keystone_settings = nil
      @keystone_node = nil
      @keystone_settings_cache_time = current_node[:ohai_time]
    end

    unless @keystone_settings && @keystone_settings.include?(instance)
      node = search_for_keystone(current_node, instance)

      ha_enabled = node[:keystone][:ha][:enabled]
      use_ssl = node["keystone"]["api"]["protocol"] == "https"
      public_host = CrowbarHelper.get_host_for_public_url(node, use_ssl, ha_enabled)

      admin_host = CrowbarHelper.get_host_for_admin_url(node, ha_enabled)

      has_default_user = node["keystone"]["default"]["create_user"]
      default_domain = "Default"
      default_domain_id = "default"
      @keystone_settings ||= Hash.new
      @keystone_settings[instance] = {
        "api_version" => node[:keystone][:api][:version],
        # This is somehwat ugly but the Juno keystonemiddleware expects the
        # version to be a "v3.0" for the v3 API instead of the "v3" or "3" that
        # is used everywhere else.
        "api_version_for_middleware" => "v%.1f" % node[:keystone][:api][:version],
        "admin_auth_url" => admin_auth_url(node, admin_host),
        "public_auth_url" => public_auth_url(node, public_host),
        "internal_auth_url" => internal_auth_url(node, admin_host),
        "unversioned_internal_auth_url" => unversioned_internal_auth_url(node, admin_host),
        "use_ssl" => use_ssl,
        "endpoint_region" => node["keystone"]["api"]["region"],
        "insecure" => use_ssl && node[:keystone][:ssl][:insecure],
        "protocol" => node["keystone"]["api"]["protocol"],
        "public_url_host" => public_host,
        "internal_url_host" => admin_host,
        "service_port" => node["keystone"]["api"]["service_port"],
        "admin_port" => node["keystone"]["api"]["admin_port"],
        "admin_token" => node["keystone"]["service"]["token"],
        "admin_tenant" => node["keystone"]["admin"]["tenant"],
        "admin_user" => node["keystone"]["admin"]["username"],
        "admin_domain" => default_domain,
        "admin_domain_id" => default_domain_id,
        "admin_password" => node["keystone"]["admin"]["password"],
        "default_tenant" => node["keystone"]["default"]["tenant"],
        "default_user" => has_default_user ? node["keystone"]["default"]["username"] : nil,
        "default_user_domain" => has_default_user ? default_domain : nil,
        "default_user_domain_id" => has_default_user ? default_domain_id : nil,
        "default_password" => has_default_user ? node["keystone"]["default"]["password"] : nil,
        "service_tenant" => node["keystone"]["service"]["tenant"],
      }
    end

    @keystone_settings[instance].merge(
      "service_user" => current_node[cookbook_name][:service_user],
      "service_password" => current_node[cookbook_name][:service_password])
  end

  private_class_method def self.search_for_keystone(node, instance)
    if @keystone_node && @keystone_node.include?(instance)
      Chef::Log.info("Keystone server found at #{@keystone_node[instance].name} [cached]")
      return @keystone_node[instance]
    end

    nodes, _, _ = Chef::Search::Query.new.search(:node, "roles:keystone-server AND keystone_config_environment:keystone-config-#{instance}")
    if nodes.first
      keystone_node = nodes.first
      keystone_node = node if keystone_node.name == node.name
    else
      keystone_node = node
    end

    @keystone_node ||= Hash.new
    @keystone_node[instance] = keystone_node

    Chef::Log.info("Keystone server found at #{@keystone_node[instance].name}")
    return @keystone_node[instance]
  end
end
