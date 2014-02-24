require_relative "spec_helper"

describe "openstack-database-service::taskmanager" do
  before do
    database_service_stubs

    @chef_run = ::ChefSpec::Runner.new ::OPENSUSE_OPTS
    @chef_run.converge "openstack-database-service::taskmanager"
  end

  it "installs the taskmanager packages" do
    expect(@chef_run).to install_package('openstack-trove-taskmanager')
  end

  it "starts the taskmanager service" do
    expect(@chef_run).to enable_service("openstack-trove-taskmanager")
  end

  describe "trove-taskmanager.conf" do
    before do
      @filename = "/etc/trove/trove-taskmanager.conf"
    end

    it "creates trove-taskmanager.conf file" do
      expect(@chef_run).to create_template(@filename).with(
        user: "openstack-trove",
        group: "openstack-trove",
        mode: 0640
        )
    end

    [/^debug = false$/,
      /^verbose = false$/,
      /^sql_connection = mysql:\/\/trove:db-pass\@127\.0\.0\.1:3306\/trove\?charset=utf8/,
      /^rabbit_host = '127.0.0.1'$/,
      /^rabbit_virtual_host = \/$/,
      /^rabbit_port = 5672$/,
      /^rabbit_userid = guest$/,
      /^rabbit_password = rabbit-pass$/,
      /^rabbit_use_ssl = false$/,
      /^trove_auth_url = http:\/\/127.0.0.1:5000\/v2.0$/,
      /^nova_compute_url = http:\/\/127.0.0.1:8774\/v2\/$/,
      /^cinder_url = http:\/\/127.0.0.1:8776\/v1\/$/,
      /^swift_url = http:\/\/127.0.0.1:8080\/v1\/$/,
      /^dns_auth_url = http:\/\/127.0.0.1:5000\/v2.0$/,
      /^log_dir = \/var\/log\/trove$/,
      /^notifier_queue_hostname = 127\.0\.0\.1$/
    ].each do |content|
      it "has a \"#{content.source[1...-1]}\" line" do
        expect(@chef_run).to render_file(@filename).with_content(content)
      end
    end
  end
end
