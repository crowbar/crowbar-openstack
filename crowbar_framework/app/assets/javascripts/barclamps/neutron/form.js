//function NeutronCisco() {
//  this.storage = $('#proposal_attributes');
//  this.target = $('#cisco_switches');
//
//  this.init();
//}
//
//NeutronCisco.prototype.init = function() {
//  this.initTemplates();
//  this.initJson();
//
//  this.renderSwitches();
//  this.registerEvents();
//};
//
//NeutronCisco.prototype.initTemplates = function() {
//  this.switchRowTemplate = Handlebars.compile(
//    $('#cisco_switch_row').html()
//  );
//};
//
//NeutronCisco.prototype.initJson = function() {
//  this.json = JSON.parse(
//    this.storage.val()
//  );
//};
//
//NeutronCisco.prototype.writeJson = function() {
//  this.storage.val(
//    JSON.stringify(this.json)
//  );
//};
//
//NeutronCisco.prototype.renderSwitches = function() {
//  if (this.json.cisco_switches) {
//    var switches = $.map(this.json.cisco_switches, function(values, key) {
//      return {
//        ip: key,
//        port: values.port,
//        user: values.user,
//        password: values.password
//      };
//    });
//  } else {
//    var switches = null;
//  }
//
//  this.target.find('table tbody').html(
//    this.switchRowTemplate({
//      switches: switches
//    })
//  );
//};
//
//NeutronCisco.prototype.registerEvents = function() {
//  var self = this;
//
//  self.target.find('input[type=text]').live('keydown', function(event) {
//    if (event.keyCode == 13) {
//      event.preventDefault();
//      self.target.find('input[type=submit]').trigger('click');
//    }
//  });
//
//  self.target.find('input[type=submit]').live('click', function(event) {
//    event.preventDefault();
//
//    if (self.duplicateSwitch()) {
//      self.target.find('table').after(
//        $.dangerMessage(
//          self.target.data('duplicate'),
//          true,
//          true
//        )
//      );
//
//      return false;
//    }
//
//    if (self.invalidSwitch()) {
//      self.target.find('table').after(
//        $.dangerMessage(
//          self.target.data('invalid'),
//          true,
//          true
//        )
//      );
//
//      return false;
//    }
//
//    if (self.json.cisco_switches == undefined) {
//      self.json.cisco_switches = {};
//    }
//
//    self.json.cisco_switches[self.getSwitchIp()] = {
//      port: self.getSwitchPort(),
//      user: self.getSwitchUsername(),
//      password: self.getSwitchPassword()
//    };
//
//    self.clearInputValues();
//    self.writeJson();
//    self.renderSwitches();
//  });
//
//  self.target.find('[data-target]').live('click', function(event) {
//    event.preventDefault();
//    delete self.json.cisco_switches[$(this).data('target')];
//
//    self.writeJson();
//    self.renderSwitches();
//  });
//};
//
//NeutronCisco.prototype.duplicateSwitch = function() {
//  if (this.json.cisco_switches) {
//    return this.getSwitchIp() in this.json.cisco_switches;
//  } else {
//    return false;
//  }
//};
//
//NeutronCisco.prototype.invalidSwitch = function() {
//  return !(this.getSwitchIp() && this.getSwitchPort() && this.getSwitchUsername() && this.getSwitchPassword());
//};
//
//NeutronCisco.prototype.getSwitchIp = function() {
//  return this.target.find('#switch_ip').val();
//};
//
//NeutronCisco.prototype.getSwitchPort = function() {
//  return this.target.find('#switch_port').val();
//};
//
//NeutronCisco.prototype.getSwitchUsername = function() {
//  return this.target.find('#switch_user').val();
//};
//
//NeutronCisco.prototype.getSwitchPassword = function() {
//  return this.target.find('#switch_password').val();
//};
//
//NeutronCisco.prototype.clearInputValues = function() {
//  this.target.find('#switch_ip, #switch_port, #switch_user, #switch_password').val('');
//};

$(document).ready(function($) {
  $('#networking_plugin').on('change', function() {
    var value = $(this).val();

    switch (value) {
      case 'linuxbridge':
        $('#networking_mode').trigger('change');
        $('#mode_container').hide(100).attr('disabled', 'disabled');

        $('#cisco_switches').hide(100).attr('disabled', 'disabled');
        break;
      case 'openvswitch':
        $('#networking_mode').trigger('change');
        $('#mode_container').show(100).removeAttr('disabled');

        $('#cisco_switches').hide(100).attr('disabled', 'disabled');
        break;
      case 'cisco':
        $('#networking_mode').trigger('change');
        $('#mode_container').show(100).removeAttr('disabled');

        if ($('#networking_mode').val() == 'vlan') {
          $('#cisco_switches').show(100).removeAttr('disabled');
        } else {
          $('#cisco_switches').hide(100).attr('disabled', 'disabled');
        }
        break;
    }
  }).trigger('change');

  $('#networking_mode').on('change', function() {
    var value = $(this).val();

    switch (value) {
      case 'vlan':
        $('#warn_ovs_vlan').show(100).removeAttr('disabled');

        if ($('#networking_plugin').val() == 'cisco') {
          $('#cisco_switches').show(100).removeAttr('disabled');
        } else {
          $('#cisco_switches').hide(100).attr('disabled', 'disabled');
        }
        break;
      default:
        $('#warn_ovs_vlan').hide(100).attr('disabled', 'disabled');
        $('#cisco_switches').hide(100).attr('disabled', 'disabled');
        break;
    }
  }).trigger('change');

  //new NeutronCisco();
});
