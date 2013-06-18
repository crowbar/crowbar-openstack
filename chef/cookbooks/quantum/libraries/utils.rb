module ::Quantum

  module_function

  def get_net_id_by_name name

    require 'csv'
    csv_data = `quantum net-list -f csv -c id -c name -- --name floating`
    Chef::Log.info("CSV data from quantum net-list by get_net_id_by_name: #{csv_data}")

    return CSV.parse(csv_data)[1][0]

  end

end
