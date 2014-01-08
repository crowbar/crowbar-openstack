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
});
