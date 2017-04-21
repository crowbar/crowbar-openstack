/**
 * Copyright 2017 FUJITSU LIMITED
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
  $('#master_notification_enable_email').on('change', function() {
    var value = $(this).val();

    if (value == 'false') {
      $('#master_smtp_host').attr('disabled', 'disabled');
      $('#master_smtp_port').attr('disabled', 'disabled');
      $('#master_smtp_user').attr('disabled', 'disabled');
      $('#master_smtp_password').attr('disabled', 'disabled');
      $('#master_smtp_from_address').attr('disabled', 'disabled');
    }
    else
    {
      $('#master_smtp_host').removeAttr('disabled');
      $('#master_smtp_port').removeAttr('disabled');
      $('#master_smtp_user').removeAttr('disabled');
      $('#master_smtp_password').removeAttr('disabled');
      $('#master_smtp_from_address').removeAttr('disabled');
    }
  }).trigger('change');
});
