require "chefspec"
require "chefspec/berkshelf"
require "chef/application"

::LOG_LEVEL = :fatal
::OPENSUSE_OPTS = {
  :platform => "opensuse",
  :version => "12.3",
  :log_level => ::LOG_LEVEL
}
::REDHAT_OPTS = {
  :platform => "redhat",
  :version => "6.3",
  :log_level => ::LOG_LEVEL
}
::UBUNTU_OPTS = {
  :platform => "ubuntu",
  :version => "12.04",
  :log_level => ::LOG_LEVEL
}

def database_service_stubs
  ::Chef::Recipe.any_instance.stub(:db_password).and_return "db-pass"
  ::Chef::Recipe.any_instance.stub(:user_password).and_return "rabbit-pass"
  ::Chef::Recipe.any_instance.stub(:secret).
    with("secrets", "openstack_identity_bootstrap_token").
    and_return "bootstrap-token"
end
