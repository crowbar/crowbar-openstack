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

var useSharedStorageSelection = null;

function setup_shared_instance_storage_check() {
  switch ($('#setup_shared_instance_storage').val()) {
  case 'true':
    $('#use_shared_instance_storage_container').hide();
    if (useSharedStorageSelection === null) {
      useSharedStorageSelection = $('#use_shared_instance_storage').val();
    }
    $('#use_shared_instance_storage').val('true').trigger('change');
    break;
  case 'false':
    if (useSharedStorageSelection !== null) {
      $('#use_shared_instance_storage').val(useSharedStorageSelection).trigger('change');
      useSharedStorageSelection = null;
    }
    $('#use_shared_instance_storage_container').show();
    break;
  }
}

$(document).ready(function($) {
  $('#setup_shared_instance_storage').on('change', setup_shared_instance_storage_check).trigger('change');
});
