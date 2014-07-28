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

  var cinder_backend_template;

  Handlebars.registerHelper('if_eq', function(a, b, opts) {
    if(a == b)
      return opts.fn(this);
    else
      return opts.inverse(this);
  });

  var use_multi_backend = $('#proposal_attributes').readJsonAttribute(
                            'use_multi_backend', false);

  function cb_cinder_volume_delete()
  {
    //FIXME: right now, there's no good way to localize strings in js :/
    if (confirm("All volumes in the backend will be made unavailable; do you really want to delete this backend?")) {
      volume_entry = $(this).data("volumeid");

      $(this).hide('slow', function() {
        // delete the backend entry from the attributes JSON
        $('#proposal_attributes').removeJsonAttribute('volumes/' + volume_entry);
        redisplay_backends();
      });
    }

    return false;
  }

  function attach_events()
  {
    $('#cinder_backends [data-change]').updateAttribute();

    $('.volume-backend-delete').on('click', cb_cinder_volume_delete);
    $('#cinder_backends [data-netapp-storage-protocol]').on('change', function() {
      var volume_id = $(this).data('volumeid');

      var netapp_storage_protocol = "#volumes_{0}_netapp_storage_protocol".format(volume_id);
      var netapp_nfs_container = "#netapp_nfs_container_{0}".format(volume_id);

      switch ($(netapp_storage_protocol).val()) {
        case 'nfs':
          $(netapp_nfs_container).show(100).removeAttr('disabled');
          break;
        default:
          $(netapp_nfs_container).hide(100).attr('disabled', 'disabled');
          break;
      }
    }).trigger('change');
    $('#cinder_backends [data-hideit]').trigger('change');
  }

  function detach_events()
  {
    $('#cinder_backends [data-change]').off('change keyup');
    $('.volume-backend-delete').off('click');
    $('#cinder_backends [data-netapp-storage-protocol]').off('change');
  }

  function redisplay_backends()
  {
    if (!cinder_backend_template) {
      cinder_backend_template = Handlebars.compile(
        $('#backend_entries').html()
      );
    }
    volumes = $('#proposal_attributes').readJsonAttribute('volumes', {});
    volume_defaults = $('#proposal_attributes').readJsonAttribute('volume_defaults', {});

    // Render forms for backend list
    $('#cinder_backends').replaceWith(
      cinder_backend_template({
        "entries": volumes,
        "use_multi_backend": use_multi_backend,
        "is_only_backend": volumes.length == 1
      })
    );

    // refresh data-change handlers
    detach_events();
    attach_events();
  }

  if (!use_multi_backend) {
    $('#volumes_0_backend_driver').on('change', function() {
      var volumes = $('#proposal_attributes').readJsonAttribute('volumes', {});
      var new_backend = $(this).val();
      var old_backend = volumes[0]["backend_driver"];
      delete volumes[0][old_backend];

      volumes[0]["backend_driver"] = new_backend;
      volumes[0][new_backend] = $('#proposal_attributes').readJsonAttribute('volume_defaults/' + new_backend);
      $('#proposal_attributes').writeJsonAttribute('volumes', volumes);

      redisplay_backends();
    });
  }

  if ($.queryString['attr_raw'] != "true") {
    redisplay_backends();
  }

  // Fix up the select elements by reading the data-initial-value attributes
  // and setting it as value (aka selecting this option by default)
  $("select[data-initial-value]").each(function(){ $(this).val($(this).data("initial-value")); });

  $('#add_cinder_backend').click(function() {
    var new_backend = {
      'backend_driver': $('#volumes_backend_driver').val(),
      'backend_name': $('#volumes_backend_name').val() || $('#volumes_backend_driver').val(),
    };
    var driver = new_backend['backend_driver'];
    new_backend[driver] = $('#proposal_attributes').readJsonAttribute('volume_defaults/' + driver);

    volumes = $('#proposal_attributes').readJsonAttribute('volumes', {});
    volumes.push(new_backend);
    $('#proposal_attributes').writeJsonAttribute('volumes', volumes);

    // Reset field entries
    $('#volumes_backend_driver').val('raw')
    $('#volumes_backend_name').val('')

    redisplay_backends();
  });


});
