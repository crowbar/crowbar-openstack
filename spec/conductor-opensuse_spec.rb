require_relative "spec_helper"

describe "openstack-database_service::conductor" do
  before do
    database_service_stubs

    @chef_run = ::ChefSpec::Runner.new ::OPENSUSE_OPTS
    @chef_run.converge "openstack-database_service::conductor"
  end

  it "installs the converge packages" do
    expect(@chef_run).to install_package('openstack-trove-conductor')
  end

  it "starts the conductor service" do
    expect(@chef_run).to enable_service("openstack-trove-conductor")
  end

  describe "trove-conductor.conf" do
    before do
      @filename = "/etc/trove/trove-conductor.conf"
    end

    it "creates the trove-conductor.conf file" do
      expect(@chef_run).to create_template(@filename).with(
        user: "openstack-trove",
        group: "openstack-trove",
        mode: 0640
        )
    end

    [/^sql_connection = mysql:\/\/trove:db-pass\@127\.0\.0\.1:3306\/trove\?charset=utf8/,
      /^trove_auth_url = http:\/\/127.0.0.1:5000\/v2.0$/
    ].each do |content|
      it "has a \"#{content.source[1...-1]}\" line" do
        expect(@chef_run).to render_file(@filename).with_content(content)
      end
    end
  end      
end
