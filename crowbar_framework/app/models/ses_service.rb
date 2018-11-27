#
# Copyright 2018, SUSE LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class SesService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "ses"
    @logger = thelogger
  end

  class << self
    # turn off multi proposal support till it really works and people ask for
    # it.
    def self.allow_multiple_proposals?
      false
    end
  end

  def create_proposal
    base = super

    #base["attributes"][@bc_name]["cinder_instance"] = Proposal.find_by(barclamp: "cinder")
    #base["attributes"][@bc_name]["nova_instance"] = Proposal.find_by(barclamp: "nova")
    #base["attributes"][@bc_name]["keystone_instance"] = Proposal.find_by(barclamp: "keystone")
    #base["attributes"][@bc_name]["glance_instance"] = Proposal.find_by(barclamp: "glance")
    secret_uuid = `uuidgen`.strip
    base["attributes"][@bc_name]["secret_uuid"] = secret_uuid
    base
  end

  def validate_proposal_after_save(proposal)
    super
  end

  def apply_role_pre_chef_call(old_role, role, all_nodes)
  end
end
