#
# Cookbook Name:: glance
# Recipe:: api
#
#

include_recipe "#{@cookbook_name}::common"

cinder_service "api"

node[:cinder][:monitor][:svcs] <<["cinder-api"]

