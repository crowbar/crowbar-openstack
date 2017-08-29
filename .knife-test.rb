# knife config file for travis-ci jobs that require knife
# set a dir for the cache in the HOME dir or it will try to write to /var/chef
cache_type "BasicFile"
cache_options(:path => "#{ENV['HOME']}/.chef/checksums")
cookbook_path "chef/cookbooks/"
