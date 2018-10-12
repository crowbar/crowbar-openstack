/**
 * Copyright 2011-2013, Dell
 * Copyright 2013-2014, SUSE LINUX Products GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

$(document).ready(function($) {

  $( "#parse_yaml" ).click(function() {
    try {
      $("#yaml_fail").hide();
      $("#yaml_success").hide();

      var raw_yaml = $("#yaml_file").val().trim();
      var ses_config = YAML.parse(raw_yaml);
      $("#yaml_success").effect("highlight", {"color": "#00FF00"}, 3000);
      $("#yaml_file").effect("highlight", {"color": "#00FF00"}, 3000);
      console.log("yaml parsed");

      /* Now that we have the yaml parsed */
      $("#ceph_conf_cluster_network").val(ses_config.ceph_conf.cluster_network).trigger('change');
      $("#ceph_conf_fsid").val(ses_config.ceph_conf.fsid).trigger('change');
      $("#ceph_conf_mon_host").val(ses_config.ceph_conf.mon_host).trigger('change');
      $("#ceph_conf_mon_initial_members").val(ses_config.ceph_conf.mon_initial_members).trigger('change');
      $("#ceph_conf_public_network").val(ses_config.ceph_conf.public_network).trigger('change');

      $("#cinder_key").val(ses_config.cinder.key).trigger('change');
      $("#cinder_rbd_store_pool").val(ses_config.cinder.rbd_store_pool).trigger('change');
      $("#cinder_rbd_store_user").val(ses_config.cinder.rbd_store_user).trigger('change');

      $("#cinder_backup_key").val(ses_config["cinder-backup"].key).trigger('change');
      $("#cinder_backup_rbd_store_pool").val(ses_config["cinder-backup"].rbd_store_pool).trigger('change');
      $("#cinder_backup_rbd_store_user").val(ses_config["cinder-backup"].rbd_store_user).trigger('change');

      $("#glance_key").val(ses_config.glance.key).trigger('change');
      $("#glance_rbd_store_pool").val(ses_config.glance.rbd_store_pool).trigger('change');
      $("#glance_rbd_store_user").val(ses_config.glance.rbd_store_user).trigger('change');

      $("#nova_rbd_store_pool").val(ses_config.nova.rbd_store_pool).trigger('change');
      $("#radosgw_urls").val(ses_config.radosgw_urls).trigger('change');

    } catch(err) {
      console.log("Failed to process the yaml " + err);
      $("#yaml_file").effect("highlight", {"color": "#FF0000"}, 3000);
      $("#yaml_fail").effect("highlight", {"color": "#FF0000"}, 3000);
    }
  });

});
