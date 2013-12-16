$(document).ready(function($) {
  $('#volume_volume_type').on('change', function() {
    var value = $(this).val();

    var types = [
      'emc',
      'netapp',
      'eqlx',
      'manual',
      'local',
      'rbd',
      'raw'
    ];

    var selector = $.map(types, function(val, index) {
      return '#{0}_container'.format(val);
    }).join(', ');

    var current = '#{0}_container'.format(
      value
    );

    $(selector).hide(100).attr('disabled', 'disabled');
    $(current).show(100).removeAttr('disabled');

    switch (value) {
      case 'local':
        $('#local_container [name="volume_volume_name"]').attr(
          'value',
          $('#raw_container [name="volume_volume_name"]').val()
        );
        break;
      case 'raw':
        $('#raw_container [name="volume_volume_name"]').attr(
          'value',
          $('#local_container [name="volume_volume_name"]').val()
        );
        break;
    }
  }).trigger('change');
});
