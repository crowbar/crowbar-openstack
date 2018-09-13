/**
 * Copyright 2011-2013, Dell
 * Copyright 2013-2018, SUSE LINUX Products GmbH
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
  function updateDBEngines() {
    // defer update of selected engines to make sure roles assignment
    // is updated by event handlers from NodeList.
    setTimeout(function() {
      var nodes = {
        postgresql: $('ul#database-server li').length,
        mysql: $('ul#mysql-server li').length
      };

      var selector = $.map(nodes, function(val, index) {
        return '#{0}_container'.format(index);
      }).join(', ');

      var currentEngines = $.grep(Object.keys(nodes), function(val) { return nodes[val] > 0; });

      var current = $.map(currentEngines, function(val, index) {
        return '#{0}_container'.format(val);
      }).join(', ');

      $(selector).hide(100).attr('disabled', 'disabled');
      $(current).show(100).removeAttr('disabled');

      // automatically select active engine only for new proposals
      // note that this check is not perfect and will trigger autoselect also for saved but not applied
      // proposals (even old ones).
      if ($('#proposal_deployment').readJsonAttribute('crowbar-applied') === false) {
        // update sql_engine if only one engine was selected and default to mysql if no roles are assigned
        var activeEngine = $('#sql_engine').val();
        if (currentEngines.length === 1) {
          activeEngine = currentEngines[0];
        } else if (currentEngines.length === 0) {
          activeEngine = 'mysql';
        }
        $('#sql_engine').val(activeEngine);
        $('#proposal_attributes').writeJsonAttribute('sql_engine', activeEngine);
      }

      // make sure all items have handlers attached
      setupEventHandlers();
    }, 0);
  }

  function setupEventHandlers() {
    $('[data-droppable=true]').off('drop', updateDBEngines).on('drop', updateDBEngines);
    $('.dropzone .delete').off('click', updateDBEngines).on('click', updateDBEngines);
    $('.dropzone .unassign').off('click', updateDBEngines).on('click', updateDBEngines);
  }

  updateDBEngines();
});
