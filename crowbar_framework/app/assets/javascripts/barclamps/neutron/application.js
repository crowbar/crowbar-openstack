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

;(function($, doc, win) {
  'use strict';

  function CiscoPorts(el, options) {
    this.root = $(el);
    this.json = {};

    this.options = $.extend(
      {
        storage: '#proposal_attributes',
        path: 'cisco_switches'
      },
      options
    );

    this.initialize();
  }

  CiscoPorts.prototype.initialize = function() {
    var self = this;

    $("#networking_plugin, #networking_mode").live(
      "change",
      function() {
        self.visualizePorts();
      }
    );

    $(document).on(
      "dynamicTableRenderedEntry",
      function() {
        self.visualizePorts();
        self.renderOptions();
      }
    );

    self.visualizePorts();
    self.prepareNodes();
    self.renderOptions();
    self.registerEvents();
  };

  CiscoPorts.prototype.visualizePorts = function() {
    var self = this;

    if (self.visualSwitches()) {
      $('#cisco_ports').show(100).removeAttr('disabled');
    } else {
      $('#cisco_ports').hide(100).attr('disabled', 'disabled');
    }
  };

  CiscoPorts.prototype.prepareNodes = function() {
    var self = this;

    $.each(self.retrieveSwitches(), function(ip, data) {
      if (data['switch_ports'] == undefined) {
        self.writeJson(
          '{0}/switch_ports'.format(ip),
          {}
        );
      } else {
        $.each(data['switch_ports'], function(node, meta) {
          $(
            '[data-name=number][data-node={0}]'.format(
              node
            )
          ).val(meta['switch_port']).trigger('change');
        });
      }
    });
  };

  CiscoPorts.prototype.renderOptions = function() {
    var self = this;

    var options = $.map(self.retrieveSwitches(), function(val, i) {
      return '<option value="{0}">{1}</option>'.format(i, i);
    });

    $('[data-name=switch]').html(options.join('')).each(
      function(index, select) {
        var select = $(select);
        var node = select.data('node');

        $.each(self.retrieveSwitches(), function(ip, data) {
          if (data['switch_ports'] && data['switch_ports'][node]) {
            select.val(ip).trigger('change');
          }
        });
      }
    );
  };

  CiscoPorts.prototype.registerEvents = function() {
    var self = this;

    $('[data-name=switch]').live('change keyup', function() {
      var node = $(this).data('node');
      var value = '';

      $.each(self.retrieveSwitches(), function(ip, data) {
        if (data['switch_ports'] && data['switch_ports'][node]) {
          self.removeJson(
            '{0}/switch_ports/{1}'.format(
              ip,
              node
            )
          );
        }
      });

      if (value == '') {
        value = {
          switch_port: $(
            '[data-name=number][data-node={0}]'.format(node)
          ).val()
        }
      }

      self.writeJson(
        '{0}/switch_ports/{1}'.format(
          $(this).val(),
          node
        ),
        value
      );

      return true;
    });

    $('[data-name=number]').live('change keyup', function() {
      var node = $(this).data('node');

      var ip = $(
        '[data-name=switch][data-node={0}]'.format(
          node
        )
      );

      self.writeJson(
        '{0}/switch_ports/{1}/switch_port'.format(
          ip.val(),
          node
        ),
        $(this).val(),
        'string'
      );

      return true;
    });

    $('[data-clear]').live('click', function(event) {
      event.preventDefault();
      var node = $(this).data('clear');

      $(
        '[data-name=number][data-node={0}]'.format(
          node
        )
      ).val('').trigger('change');

      $(
        '[data-name=switch][data-node={0}]'.format(
          node
        )
      ).val('').trigger('change');
    });
  };

  CiscoPorts.prototype.retrieveSwitches = function() {
    return $(this.options.storage).readJsonAttribute(
      this.options.path,
      {}
    );
  };

  CiscoPorts.prototype.writeJson = function(key, value, type) {
    return $(this.options.storage).writeJsonAttribute(
      '{0}/{1}'.format(
        this.options.path,
        key
      ),
      value,
      type
    );
  };

  CiscoPorts.prototype.removeJson = function(key, value, type) {
    return $(this.options.storage).removeJsonAttribute(
      '{0}/{1}'.format(
        this.options.path,
        key
      ),
      value,
      type
    );
  };

  CiscoPorts.prototype.visualSwitches = function() {
    return !$.isEmptyObject(this.retrieveSwitches())
      && $('#networking_plugin').val() == 'cisco'
      && $('#networking_mode').val() == 'vlan';
  };

  $.fn.ciscoPorts = function(options) {
    return this.each(function() {
      new CiscoPorts(this, options);
    });
  };
}(jQuery, document, window));

$(document).ready(function($) {
  $('#networking_plugin').on('change', function() {
    var value = $(this).val();
    var networking_mode = $('#networking_mode')
    var non_forced_mode = networking_mode.data('non-forced');

    switch (value) {
      case 'linuxbridge':
        if (non_forced_mode == undefined) {
          networking_mode.data('non-forced', networking_mode.val());
        }
        networking_mode.val('vlan').trigger('change');
        $('#mode_container').hide(100).attr('disabled', 'disabled');

        $('#vmware_container').hide(100).attr('disabled', 'disabled');
        break;
      case 'openvswitch':
        if (non_forced_mode != undefined) {
          networking_mode.val(non_forced_mode);
          networking_mode.removeData('non-forced');
        }

        $('#mode_container').show(100).removeAttr('disabled');
        networking_mode.trigger('change');

        $('#vmware_container').hide(100).attr('disabled', 'disabled');
        break;
      case 'cisco':
        if (non_forced_mode != undefined) {
          networking_mode.val(non_forced_mode);
          networking_mode.removeData('non-forced');
        }

        $('#mode_container').show(100).removeAttr('disabled');
        networking_mode.trigger('change');

        $('#vmware_container').hide(100).attr('disabled', 'disabled');
        break;
      case 'vmware':
        if (non_forced_mode == undefined) {
          networking_mode.data('non-forced', networking_mode.val());
        }
        networking_mode.val('gre').trigger('change');
        $('#mode_container').hide(100).attr('disabled', 'disabled');

        $('#vmware_container').show(100).removeAttr('disabled');
        break;
    }
  }).trigger('change');

  $('#networking_mode').on('change', function() {
    var value = $(this).val();

    switch (value) {
      case 'vlan':
        $('#warn_ovs_vlan').show(100).removeAttr('disabled');
        $('#num_vlans_container').show(100).removeAttr('disabled');

        if ($('#networking_plugin').val() == 'cisco') {
          $('#cisco_switches').show(100).removeAttr('disabled');
        } else {
          $('#cisco_switches').hide(100).attr('disabled', 'disabled');
        }
        break;
      default:
        $('#warn_ovs_vlan').hide(100).attr('disabled', 'disabled');
        $('#cisco_switches').hide(100).attr('disabled', 'disabled');
        $('#num_vlans_container').hide(100).attr('disabled', 'disabled');
        break;
    }
  }).trigger('change');

  $('#cisco_ports table').ciscoPorts();
});
