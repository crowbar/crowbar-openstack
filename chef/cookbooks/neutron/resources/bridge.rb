actions :create

attribute :network_name, :kind_of => String, :required => true
attribute :slaves, :kind_of => Array
attribute :type, :equal_to => ["linuxbridge"], :required => true
attribute :neutron_cmd, :kind_of => String, :required => true
