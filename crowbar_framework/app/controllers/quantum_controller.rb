# Copyright 2011, Dell 
# 
# Licensed under the Apache License, Version 2.0 (the "License"); 
# you may not use this file except in compliance with the License. 
# You may obtain a copy of the License at 
# 
#  http://www.apache.org/licenses/LICENSE-2.0 
# 
# Unless required by applicable law or agreed to in writing, software 
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
# See the License for the specific language governing permissions and 
# limitations under the License. 
# 

class QuantumController < BarclampController
  def initialize
    @service_object = QuantumService.new logger
  end

  def cisco_topology
    if request.post?
      nodes_req = {}
      params.each do |k, v|
        if k.starts_with? "node:"
          parts = k.split ':'
          node = parts[1]
          area = parts[2]
          nodes_req[node] = {} if nodes_req[node].nil?
          nodes_req[node][area] = (v.empty? ? nil : v)
        end
      end
      nodes_req.each do |node_name, values|
        begin
          dirty = false
          node = NodeObject.find_node_by_name node_name
          if !(@service_object.get_cisco_switch_value(node, 'ip') == values['switch_ip'])
            @service_object.set_cisco_switch_value(node, 'ip', values['switch_ip'])
            dirty = true
          end
          if !(@service_object.get_cisco_switch_value(node, 'port') == values['switch_port'])
            @service_object.set_cisco_switch_value(node, 'port', values['switch_port'])
            dirty = true
          end
          if dirty
            node.save
          end
        rescue Exception=>e
          failed << node_name
        end 
      end
    end
    @nodes = {}
    NodeObject.find("roles:nova-multi-compute-*").each do |node|
      @service_object.set_cisco_switch_value(node, 'ip', @service_object.get_cisco_switch_value(node, 'ip'))
      @service_object.set_cisco_switch_value(node, 'port', @service_object.get_cisco_switch_value(node, 'port'))
      @nodes[node.handle] = node
    end
    render :template => "barclamp/#{@bc_name}/cisco_topology.html.haml"
  end
end

