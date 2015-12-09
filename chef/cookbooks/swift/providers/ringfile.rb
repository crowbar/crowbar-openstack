#
# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: andi abes
#

##
# This LWRP will read the current state of a current ring, by executing
# swift-ring-builder and parsing its output. It would then compare the
# desired set of disks to the disks present.
# It currently does not change parameters (zone assignment or weight).
# to achieve that, you'd have to remove and readd the disk.

if __FILE__ == $0
  def action(sym)
  end

  class Chef
    class Log
      def self.debug(s)
        puts s
      end
    end
  end
end

##
# some internal data structs to hold ring info read from existing files

class RingInfo
  attr_accessor :partitions, :replicas, :zones, :device_num, :devices, :min_part_hours

  class RingDeviceInfo
    attr_accessor :id, :region, :zone, :ip, :port, :name, :weight, :partitions

    def initialize
      Chef::Log.debug "new device"
      self
    end
    def to_s
      s = "@#{@id}:#{@zone}[#{@ip}:#{@port}]/#{@name}"
    end
  end

  def initialize
    @devices = {}
    self
  end

  def self.dev_key ip,port,name
    "#{ip}:#{port.to_s}-#{name}"
  end

  def add_device d
    Chef::Log.debug "added device @ip #{d.ip}:#{d.port}"
    key = RingInfo.dev_key d.ip,d.port ,d.name
    @devices[key] = d
  end

  def to_s
    s = ""
    #s <<"r:" << @replicas <<"z:" << @zones
    devices.each { |d|
      s << "\n  " << d.to_s
    }
  end
end

def load_current_resource
  name = @new_resource.name
  name = "/etc/swift/#{name}"
  @current_resource = Chef::Resource::SwiftRingfile.new(name)
  @ring_test = nil
  Chef::Log.info("parsing ring-file for #{name}")
  IO.popen("swift-ring-builder #{name}") { |pipe|
    ring_txt = pipe.readlines
    Chef::Log.debug("raw ring info:#{ring_txt}")
    @ring_test = scan_ring_desc ring_txt
    Chef::Log.debug("at end of load, current ring is: #{@ring_test.to_s}")
  }
  compute_deltas
end

def scan_ring_desc(input)

  r = RingInfo.new
  state = :init
  next_state = "" # if the current state is ignore, this is the next state
  ignore_count = 0 # the number of lines to ignore
  input.each { |line|
    case state
    when :init
      state = :gen_info
      next

    when :ignore
      Chef::Log.debug("ignoring line: " + line)
      ignore_count -= 1
      if (ignore_count == 0)
        state = next_state
      end
      next

    when :gen_info
      Chef::Log.debug("reading gen info: " + line)
      line =~ /^(\d+) partitions, ([0-9.]+) replicas, (\d+) regions, (\d+) zones, (\d+) devices,.*$/
      r.partitions = $1
      r.replicas = $2
      r.zones = $4
      r.device_num = $5
      state = :ignore
      next_state = :dev_info
      ignore_count = 2
      next

    when :dev_info
      # Line looks like this:
      #   id  region  zone      ip address  port  replication ip  replication port      name weight partitions balance meta
      #   0       1     0  192.168.125.14  6000  192.168.125.14              6000 2d4dc9923ed244dc9cac8f283ca79748  99.00          0 -100.00
      Chef::Log.debug("reading dev info: " + line)
      line =~ /^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\S+)\s+([0-9.]+)\s+(\d+)\s*([-0-9.]+)\s*$/
      if $~.nil?
        raise "failed to parse: #{line}"
      else
        Chef::Log.debug("matched: #{$~[0]}")
      end
      dev = RingInfo::RingDeviceInfo.new
      dev.id = $1
      dev.region = $2
      dev.zone = $3
      dev.ip = $4
      dev.port = $5
      replication_ip = $6
      replication_port = $7
      dev.name = $8
      dev.weight = $9
      dev.partitions = $10
      r.add_device dev
    end
  }
  r
end

###
# compute disks to be added or removed (and update the dirty flag)
def compute_deltas
  req_disks = @new_resource.disks
  keyed_req = {}  # for easy lookup, make a map of the requested disks
  cur = @ring_test
  name = @new_resource.name
  @to_add = []
  @to_rem = []

  ## figure out which disks need adding
  req_disks.each {|disk|
    key = RingInfo.dev_key disk[:ip],disk[:port],disk[:dev_name]
    @to_add << disk unless cur and cur.devices[key] # add unless present
    keyed_req[key] = disk
  }

  ### figure out which disks need removing
  cur.devices.each {|key, d|
    @to_rem << d unless keyed_req[key] # remove unless still requested
  } if cur

  Chef::Log.info("disks, to add #{@to_add.length} , to remove: #{@to_rem.length}")
  Chef::Log.debug("disks, to add #{@to_add.join(";")} , to remove: #{@to_rem.join(";")}")

end

action :apply do
  name = @new_resource.name
  cur = @ring_test
  Chef::Log.info("current content of: #{name} #{(cur.nil? ? "-not there" : cur.to_s)}")

  ## make sure file exists
  create_ring

  # if we're changing the ring, make sure that file timestamps differ somewhat
  if @to_add.length > 0 or @to_rem.length > 0
    sleep 0.1
  end

  @to_add.each do |d|
    execute "add disk #{d[:ip]}:#{d[:port]}/#{d[:dev_name]} to #{name}" do
      user node[:swift][:user]
      group node[:swift][:group]
      command "swift-ring-builder #{name} add z#{d[:zone]}-#{d[:ip]}:#{d[:port]}/#{d[:dev_name]} #{d[:weight]}"
      cwd "/etc/swift"
    end
  end

  @to_rem.each do |d|
    execute "remove disk #{d.id} from #{name}" do
      user node[:swift][:user]
      group node[:swift][:group]
      command "swift-ring-builder #{name} remove d#{d.id} "
      cwd "/etc/swift"
    end
  end
end

action :rebalance do
  name = @current_resource.name
  dirty = false

  ring_data_mtime = ::File.new(name).mtime   if ::File.exist?(name)
  ring_data_mtime ||= File.new(name).mtime   if ::File.exist?(name)
  ring_data_mtime ||= 0
  ring_name = name.sub(/^(.*)\..*$/, '\1.ring.gz')
  ring_file_mtime = (::File.exist?(ring_name) ? ::File.mtime(ring_name) : -1)
  dirty = true if (ring_data_mtime.to_i > ring_file_mtime.to_i)

  Chef::Log.info("current status for: #{name} is #{dirty ? "dirty" : "not-dirty"} #{ring_name} #{ring_data_mtime.to_i}/#{ring_file_mtime.to_i}")

  execute "rebalance ring for #{name}" do
    user node[:swift][:user]
    group node[:swift][:group]
    command "swift-ring-builder #{name} rebalance"
    cwd "/etc/swift"
    returns [0,1]  # returns 1 if it didn't do anything, 2 on
  end if dirty

  # if no rebalance was needed, but the the ring file is not there, make sure to make it.
  if !::File.exist?(ring_name) then
    dirty = true
    execute "writeout ring for #{name}" do
      user node[:swift][:user]
      group node[:swift][:group]
      command "swift-ring-builder #{name} write_ring"
      cwd "/etc/swift"
      returns [0,1]  ## returns 1 if it didn't do anything, 2 on error.
    end
  end

  @new_resource.updated_by_last_action(dirty)
end

def create_ring
  name = @new_resource.name
  mh = @new_resource.min_part_hours ? @new_resource.min_part_hours : 1
  parts = @new_resource.partitions ? @new_resource.partitions : 18
  replicas = @new_resource.replicas ? @new_resource.replicas : 3

  execute "create #{name} ring" do
    user node[:swift][:user]
    group node[:swift][:group]
    command "swift-ring-builder #{name} create #{parts}  #{replicas} #{mh}"
    creates "/etc/swift/#{name}"
    cwd "/etc/swift"
  end
end

if __FILE__ == $0
  test_str_juno = <<TEST
/etc/swift/account.builder, build version 1
65536 partitions, 3.000000 replicas, 1 regions, 1 zones, 1 devices, 0.00 balance
The minimum number of hours before a partition can be reassigned is 24
Devices:    id  region  zone      ip address  port  replication ip  replication port      name weight partitions balance meta
             0       1     0  192.168.125.10  6002  192.168.125.10              6002 04cc15ee94ff41169b5c30c927e82bd7  99.00     196608    0.00
TEST

  test_str_liberty = <<TEST
/etc/swift/object.builder, build version 4
65536 partitions, 3.000000 replicas, 1 regions, 2 zones, 4 devices, 100.00 balance, 0.00 dispersion
The minimum number of hours before a partition can be reassigned is 24
The overload factor is 0.00% (0.000000)
Devices:    id  region  zone      ip address  port  replication ip  replication port      name weight partitions balance meta
             0       1     0  192.168.125.14  6000  192.168.125.14              6000 2d4dc9923ed244dc9cac8f283ca79748  99.00          0 -100.00
             1       1     1  192.168.125.15  6000  192.168.125.15              6000 98efd70297d547f2b90b697362e10b2c  99.00          0 -100.00
             2       1     0  192.168.125.15  6000  192.168.125.15              6000 bd0e9f3cc6ab4a67abf99d3789f8daaa  99.00          0 -100.00
             3       1     1  192.168.125.13  6000  192.168.125.13              6000 69cb18d1fac847269b6183242db5c731  99.00          0 -100.00
TEST

  puts "=== Juno ==="
  r = scan_ring_desc test_str_juno.lines
  puts "no r for you \n\n\n" if r.nil?
  puts r.to_s

  puts ""

  puts "=== Liberty ==="
  r = scan_ring_desc test_str_liberty.lines
  puts "no r for you \n\n\n" if r.nil?
  puts r.to_s
end
