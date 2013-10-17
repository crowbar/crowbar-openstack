module ::Neutron

  module_function

  def get_net_id_by_name name, neutron_cmd

    require 'csv'

    csv_data = `#{neutron_cmd} net-list -f csv -c id -c name -- --name floating`
    Chef::Log.info("CSV data from neutron net-list by get_net_id_by_name: #{csv_data}")

    return CSV.parse(csv_data)[1][0]

  end

end
