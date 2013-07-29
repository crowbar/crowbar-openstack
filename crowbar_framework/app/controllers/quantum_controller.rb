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
          if !(get_cisco_switch_value(node, 'ip') == values['switch_ip'])
            set_cisco_switch_value(node, 'ip', values['switch_ip'])
            dirty = true
          end
          if !(get_cisco_switch_value(node, 'port') == values['switch_port'])
            set_cisco_switch_value(node, 'port', values['switch_port'])
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
      set_cisco_switch_value(node, 'ip', get_cisco_switch_value(node, 'ip'))
      set_cisco_switch_value(node, 'port', get_cisco_switch_value(node, 'port'))
      @nodes[node.handle] = node
    end
    render :template => "barclamp/#{@bc_name}/cisco_topology.html.haml"
  end

  private

  def set_cisco_switch_value(node, value_name, value)
     return nil if node.crowbar["crowbar"].nil?
     node.crowbar["crowbar"]["cisco_switch"] = {} if node.crowbar["crowbar"]["cisco_switch"].nil?
     node.crowbar["crowbar"]["cisco_switch"][value_name] = value
  end

  def get_cisco_switch_value(node, value_name)
     return "" if node.crowbar["crowbar"].nil?
     return "" if node.crowbar["crowbar"]["cisco_switch"].nil?
     node.crowbar["crowbar"]["cisco_switch"][value_name] || ""
   end

end

