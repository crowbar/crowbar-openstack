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

  def render_switch
    @switch_ip = params[:switch_ip]
    @switch_port = params[:switch_port]
    @switch_user = params[:switch_user]
    @switch_password = params[:switch_password]

    if (@switch_ip.nil? or @switch_ip.empty? or
        @switch_port.nil? or @switch_port.empty? or
        @switch_user.nil? or @switch_user.empty? or
        @switch_password.nil? or @switch_password.empty?)
      render :text=>"Invalid parameters", :status => 400
      return
    end
    respond_to do |format|
      format.html { render :partial => 'barclamp/quantum/edit_cisco_switch' }
    end
  end

  def render_switch_ports
    @switches = params[:switches]
    @nodes = {}
    unless @switches.empty?
      NodeObject.find("roles:nova-multi-compute-*").each do |node|
        tmpnode = {}
        tmpnode["name"] = node.handle
        @switches.each do |ip,values|
          if not values["switch_ports"].nil? and ! values["switch_ports"][node.handle].nil?
            tmpnode["switch_ip"] = ip
            tmpnode["switch_port"] = values["switch_ports"][node.handle]["switch_port"]
          end
        end
        @nodes[node.handle] = tmpnode
      end
    end
    respond_to do |format|
      format.html { render :partial => 'barclamp/quantum/edit_cisco_switch_ports' }
    end
  end
end

