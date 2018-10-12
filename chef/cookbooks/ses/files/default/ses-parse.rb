#!/usr/bin/ruby

require 'yaml'
config = ARGV[0]
if config != nil
   config = YAML.load_file(config)
   puts "Reading SES config from path: " + ARGV[0]
else
   puts "Please specify config path as argument"
   exit
end
$ceph_conf_cluster_network = config['ceph_conf']['cluster_network']
$ceph_conf_fsid = config['ceph_conf']['fsid']
$ceph_conf_mon_host = config['ceph_conf']['mon_host']
$ceph_conf_mon_initial_members = config['ceph_conf']['mon_initial_members']
$ceph_conf_public_network = config['ceph_conf']['public_network']
$cinder_key = config['cinder']['key']
$cinder_rbd_store_pool = config['cinder']['rbd_store_pool']
$cinder_rbd_store_user = config['cinder']['rbd_store_user']
$cinder_backup_key = config['cinder-backup']['key']
$cinder_backup_rbd_store_pool = config['cinder-backup']['rbd_store_pool']
$cinder_backup_rbd_store_user = config['cinder-backup']['rbd_store_user']
$glance_key = config['glance']['key']
$glance_rbd_store_pool = config['glance']['rbd_store_pool']
$glance_rbd_store_user = config['glance']['rbd_store_user']
$nova_rbd_store_pool = config['nova']['rbd_store_pool']
$radosgw_urls = config['radosgw_urls']

puts "ceph_conf_cluster_network:  #$ceph_conf_cluster_network"
puts "ceph_conf_fsid:  #$ceph_conf_fsid"
puts "ceph_conf_mon_host:  #$ceph_conf_mon_host"
puts "ceph_conf_mon_initial_members:  #$ceph_conf_mon_initial_members"
puts "ceph_conf_public_network :  #$ceph_conf_public_network "
puts "cinder_key:  #$cinder_key"
puts "cinder_rbd_store_pool:  #$cinder_rbd_store_pool"
puts "cinder_rbd_store_user:  #$cinder_rbd_store_user"
puts "cinder_backup_key:  #$cinder_backup_key"
puts "cinder_backup_rbd_store_pool:  #$cinder_backup_rbd_store_pool"
puts "cinder_backup_rbd_store_user :  #$cinder_backup_rbd_store_user"
puts "glance_key:  #$glance_key"
puts "glance_rbd_store_pool:  #$glance_rbd_store_pool"
puts "glance_rbd_store_user:  #$glance_rbd_store_user"
puts "nova_rbd_store_pool:  #$nova_rbd_store_pool"
puts "radosgw_urls:  #$radosgw_urls"
