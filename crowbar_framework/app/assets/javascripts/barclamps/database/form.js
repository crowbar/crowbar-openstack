$(document).ready(function($) {
  $('#sql_engine').on('change', function() {
    var value = $(this).val();

    var types = [
      'mysql',
      'postgresql'
    ];

    var selector = $.map(types, function(val, index) {
      return '#{0}_container'.format(val);
    }).join(', ');

    var current = '#{0}_container'.format(
      value
    );

    $(selector).hide(100).attr('disabled', 'disabled');
    $(current).show(100).removeAttr('disabled');
  }).trigger('change');
});
