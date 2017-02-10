#
# Copyright 2017, SUSE Linux GmbH
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

require_relative '../chef/cookbooks/neutron/libraries/helpers'


describe 'yaml serialization' do
  it 'can deal with symbols' do
    yaml = NeutronHelper.serialize_to_yaml({:key => 'value'})

    expect(yaml).to eq <<-EOF.gsub /^\s+/, ''
    ---
    key: value
    EOF
  end
end


describe 'make config' do
  it 'adds environment variables' do
    defaults = {'hatool' => {'env' => {'somekey' => 'somevalue'}}}

    config = NeutronHelper.make_l3_ha_service_config defaults, true do |env|
      env['other_key'] = 'other_value'
    end

    settings = YAML.load config

    expected = {
        'hatool' => {
            'env' => {
                'somekey' => 'somevalue',
                'other_key' => 'other_value'
            },
            'insecure' => 'true'
        }
    }
    expect(settings).to eq expected
  end

  it 'sets insecure flag' do
    defaults = {'hatool' => {'env' => {'somekey' => 'somevalue'}}}

    config = NeutronHelper.make_l3_ha_service_config defaults, true do |env|
      env['other_key'] = 'other_value'
    end

    settings = YAML.load config

    expect(settings['hatool']['insecure']).to eq 'true'
  end

  it 'leaves defaults at their value' do
    defaults = {'hatool' => {'env' => {'somekey' => 'somevalue'}}}

    config = NeutronHelper.make_l3_ha_service_config defaults, true do |env|
      env['other_key'] = 'other_value'
    end

    YAML.load config

    expect(defaults).to eq( {'hatool' => {'env' => {'somekey' => 'somevalue'}}})
  end
end
