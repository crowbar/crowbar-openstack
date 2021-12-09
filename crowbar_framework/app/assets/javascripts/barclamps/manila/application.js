/**
 * Copyright 2015 SUSE Linux GmbH
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

  var manila_backend_template;

  Handlebars.registerHelper('if_eq', function(a, b, opts) {
    if(a == b)
      return opts.fn(this);
    else
      return opts.inverse(this);
  });

  function cb_manila_share_delete()
  {
    //FIXME: right now, there's no good way to localize strings in js :/
    if (confirm("All shares in the backend will be made unavailable; do you really want to delete this backend?")) {
      var share_entry = $(this).data("shareid");

      // delete the backend entry from the attributes JSON
      $('#proposal_attributes').removeJsonAttribute('shares/' + share_entry);

      $('#share-entry-' + share_entry).hide('slow', function() {
        redisplay_backends();
      });
    }

    return false;
  }

  function attach_events()
  {
    $('#manila_backends [data-change]').updateAttribute();

    $('.share-backend-delete').on('click', cb_manila_share_delete);
    $('#manila_backends [data-hideit]').trigger('change');
    $('#manila_backends [data-showit]').trigger('change');
  }

  function detach_events()
  {
    $('#manila_backends [data-change]').off('change keyup');
    $('.share-backend-delete').off('click');
  }

  function redisplay_backends()
  {
    if (!manila_backend_template) {
      manila_backend_template = Handlebars.compile(
        $('#backend_entries').html()
      );
    }
    var shares = $('#proposal_attributes').readJsonAttribute('shares', {});

    // Render forms for backend list
    $('#manila_backends').replaceWith(
      manila_backend_template({
        "entries": shares,
        "is_only_backend": shares.length == 1
      })
    );

    // Make newly-added password fields toggleable
    $('input[type=password]').hideShowPassword();

    // Fix up the select elements by reading the data-initial-value attributes
    // and setting it as value (aka selecting this option by default)
    $("#manila_backends select[data-initial-value]").each(function(){ $(this).val($(this).data("initial-value").toString()); });

    // refresh data-change handlers
    detach_events();
    attach_events();
  }

  if ($.queryString['attr_raw'] != "true") {
    redisplay_backends();
  }

  $('#add_manila_backend').click(function() {
    var new_backend = {
      'backend_driver': $('#shares_backend_driver').val(),
      'backend_name': $('#shares_backend_name').val() || $('#shares_backend_driver').val(),
    };
    var driver = new_backend['backend_driver'];
    new_backend[driver] = $('#proposal_attributes').readJsonAttribute('share_defaults/' + driver);

    shares = $('#proposal_attributes').readJsonAttribute('shares', {});
    shares.push(new_backend);
    $('#proposal_attributes').writeJsonAttribute('shares', shares);

    // Reset field entries
    $('#shares_backend_driver').val('generic')
    $('#shares_backend_name').val('')

    redisplay_backends();
  });

});
