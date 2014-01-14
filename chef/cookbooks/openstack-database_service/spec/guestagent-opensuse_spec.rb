require_relative "spec_helper"

describe "openstack-database_service::guestagent" do
  before do
    database_service_stubs

    @chef_run = ::ChefSpec::Runner.new ::OPENSUSE_OPTS
    @chef_run.converge "openstack-database_service::guestagent"
  end

  it "installs the guestagent packages" do
    expect(@chef_run).to install_package('openstack-trove-guestagent')
  end

  it "starts the guestagent service" do
    expect(@chef_run).to enable_service("openstack-trove-guestagent")
  end

  describe "trove-guestagent.conf" do
    before do
      @filename = "/etc/trove/trove-guestagent.conf"
    end

    it "creates trove-guestagent.conf file" do
      expect(@chef_run).to create_template(@filename).with(
        user: "openstack-trove",
        group: "openstack-trove",
        mode: 0640
        )
    end

    [/^debug = false$/,
      /^verbose = false$/,
      /^sql_connection = mysql:\/\/trove:db-pass\@127\.0\.0\.1:3306\/trove\?charset=utf8/,
      /^bind_host = 127.0.0.1$/,
      /^bind_port = 8778$/,
      /^rabbit_password = rabbit-pass$/,
      /^rabbit_host = 127.0.0.1$/,
      /^trove_auth_url = http:\/\/127.0.0.1:5000\/v2.0$/,
      /^swift_url = http:\/\/127.0.0.1:8080\/v1\/$/,
      /^log_dir = \/var\/log\/trove$/,
      /^log_file = trove-guestagent.log$/
    ].each do |content|
      it "has a \"#{content.source[1...-1]}\" line" do
        expect(@chef_run).to render_file(@filename).with_content(content)
      end
    end
  end
end
