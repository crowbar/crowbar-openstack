/**
 * Copyright 2011-2013, Dell
 * Copyright 2013-2015, SUSE LINUX Products GmbH
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

    $("#networking_plugin, #ml2_type_drivers, #ml2_mechanism_drivers").live(
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
      && $('#networking_plugin').val() == 'ml2'
      && $('#ml2_mechanism_drivers').val().indexOf('cisco_nexus') >= 0
      && $('#ml2_type_drivers').val().indexOf('vlan') >= 0;
  };

  $.fn.ciscoPorts = function(options) {
    return this.each(function() {
      new CiscoPorts(this, options);
    });
  };
}(jQuery, document, window));

function networking_plugin_check() {
  switch ($('#networking_plugin').val()) {
  case 'ml2':
    $('#vmware_container').hide();
    $('#ml2_mechanism_drivers_container').show();
    $('#ml2_type_drivers_container').show();
    $('#ml2_type_drivers_default_provider_network_container').show();
    $('#ml2_type_drivers_default_tenant_network_container').show();
    ml2_type_drivers_check();
    ml2_mechanism_drivers_check();
    break;
  case 'vmware':
    $('#vmware_container').show();
    $('#ml2_mechanism_drivers_container').hide();
    $('#ml2_type_drivers_container').hide();
    $('#ml2_type_drivers_default_provider_network_container').hide();
    $('#ml2_type_drivers_default_tenant_network_container').hide();
    $('#num_vlans_container').hide();
    $('#gre_container').hide();
    $('#vxlan_container').hide();
    $('#cisco_switches').hide();
    $('#cisco_ports').hide();
    break;
  }
}

function ml2_type_drivers_check() {
  var values = $('#ml2_type_drivers').val() || [];
  if (values.indexOf("vlan") >= 0) {
    $('#num_vlans_container').show();
  } else {
    $('#num_vlans_container').hide();
  }

  if (values.indexOf("gre") >= 0) {
    $('#gre_container').show();
  } else {
    $('#gre_container').hide();
  }

  if (values.indexOf("vxlan") >= 0) {
    $('#vxlan_container').show();
  } else {
    $('#vxlan_container').hide();
  }

  var use_l2pop = (values.indexOf("gre") >= 0 || values.indexOf("vxlan") >= 0);
  $('#proposal_attributes').writeJsonAttribute('use_l2pop', use_l2pop);

  if (values.length <= 1) {
    $('#ml2_type_drivers_default_provider_network_container').hide();
    $('#ml2_type_drivers_default_tenant_network_container').hide();
    if (values.length == 1) {
      $('#ml2_type_drivers_default_tenant_network').val(values[0]).trigger('change');
      $('#ml2_type_drivers_default_provider_network').val(values[0]).trigger('change');
    }
  } else {
    $('#ml2_type_drivers_default_provider_network_container').show();
    $('#ml2_type_drivers_default_tenant_network_container').show();
  }
}

var ovsSelection = null

function ml2_mechanism_drivers_check() {
  var values = $('#ml2_mechanism_drivers').val() || [];
  if (values.indexOf("cisco_nexus") >= 0) {
    $('#cisco_switches').show();
    // auto-select openvswitch if cisco is selected
    if (values.indexOf("openvswitch") < 0) {
      values.push("openvswitch");
      $("#ml2_mechanism_drivers").val(values).trigger('change');
    }
    var type_drivers = $('#ml2_type_drivers').val() || [];
    if (type_drivers.indexOf('vlan') == -1) {
        type_drivers.push('vlan')
        $('#ml2_type_drivers').val(type_drivers).trigger('change');
    }
  } else {
    $('#cisco_switches').hide();
  }

  // hide uneeded typedriver fields if only linuxbrige is selected
  // and autoselect the vlan type driver
  if (values.length == 1 && values[0] == "linuxbridge") {
    $('#ml2_type_drivers_container').hide();
    $('#ml2_type_drivers_default_provider_network_container').hide();
    $('#ml2_type_drivers_default_tenant_network_container').hide();
    $('#vxlan_group_container').show();
    // remember previously selected values for ovs, avoid overwriting remembered
    // values, e.g. when switching back to ml2 from vmware.
    if (ovsSelection == null) {
      ovsSelection = {
        type_drivers: $('#ml2_type_drivers').val(),
        provider_type: $('#ml2_type_drivers_default_provider_network').val(),
        tenant_type: $('#ml2_type_drivers_default_tenant_network').val()
      };
    }
    $('#ml2_type_drivers').val(['vlan']).trigger('change');
    $('#ml2_type_drivers_default_tenant_network').val('vlan').trigger('change');
    $('#ml2_type_drivers_default_provider_network').val('vlan').trigger('change');
  } else {
    $('#ml2_type_drivers_container').show();
    $('#ml2_type_drivers_default_provider_network_container').show();
    $('#ml2_type_drivers_default_tenant_network_container').show();
    $('#vxlan_group_container').hide();
  }

  if (values.indexOf("openvswitch") >= 0) {
    if (ovsSelection != null ) {
      // We must be switching back from "linuxbridge", restore previously
      // selected values.
      $('#ml2_type_drivers').val(ovsSelection.type_drivers).trigger('change');
      $('#ml2_type_drivers_default_tenant_network').val(ovsSelection.tenant_type).trigger('change');
      $('#ml2_type_drivers_default_provider_network').val(ovsSelection.provider_type).trigger('change');
      ovsSelection = null;
    }
  }

  // we might have updated the type drivers
  ml2_type_drivers_check();
}

$(document).ready(function($) {
  networking_plugin_check();
  ml2_mechanism_drivers_check();

  $('#networking_plugin').on('change', networking_plugin_check).trigger('change');
  $('#ml2_type_drivers').on('change', ml2_type_drivers_check);
  $('#ml2_mechanism_drivers').on('change', ml2_mechanism_drivers_check);

  $('#cisco_ports table').ciscoPorts();
});
