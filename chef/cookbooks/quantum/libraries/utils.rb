module ::Quantum

  module_function

  def get_net_id_by_name name, use_insecure

    require 'csv'
    quantum_cmd = 'quantum'
    quantum_cmd = 'quantum --insecure' if use_insecure

    csv_data = `#{quantum_cmd} net-list -f csv -c id -c name -- --name floating`
    Chef::Log.info("CSV data from quantum net-list by get_net_id_by_name: #{csv_data}")

    return CSV.parse(csv_data)[1][0]

  end

end
