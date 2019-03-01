def upgrade(ta, td, a, d)
  fields = ["type", "boot", "console", "deploy", "inspect", "management", "power", "raid"]

  # init empty attributes with defaults
  fields.each do |field|
    attribute = "enabled_" + (field == "type" ? "hardware_types" : "#{field}_interfaces")
    a[attribute] ||= ta[attribute]
  end

  # migrate classic drivers to new form
  unless a["enabled_drivers"].nil? || a["enabled_drivers"].empty?
    # based on https://docs.openstack.org/ironic/pike/admin/upgrade-to-hardware-types.html
    mapping = {
      "agent_ilo" => {
        type: "ilo",
        boot: "ilo-virtual-media",
        console: "ilo",
        deploy: "direct",
        inspect: "ilo",
        management: "ilo",
        power: "ilo",
        raid: "agent"
      },
      "agent_ipmitool" => {
        type: "ipmi",
        boot: "pxe",
        deploy: "direct",
        inspect: "inspector",
        management: "ipmitool",
        power: "ipmitool",
        raid: "agent"
      },
      "agent_ipmitool_socat" => {
        type: "ipmi",
        boot: "pxe",
        console: "ipmitool-socat",
        deploy: "direct",
        inspect: "inspector",
        management: "ipmitool",
        power: "ipmitool",
        raid: "agent"
      },
      "agent_irmc" => {
        type: "irmc",
        boot: "irmc-virtual-media",
        deploy: "direct",
        inspect: "irmc",
        management: "irmc",
        power: "irmc",
        raid: "irmc"
      },
      "agent_pxe_oneview" => {
        type: "oneview",
        boot: "pxe",
        deploy: "oneview-direct",
        inspect: "oneview",
        management: "oneview",
        power: "oneview",
        raid: "agent"
      },
      "agent_ucs" => {
        type: "cisco-ucs-managed",
        boot: "pxe",
        deploy: "direct",
        inspect: "inspector",
        management: "ucsm",
        power: "ucsm",
        raid: "agent"
      },
      "iscsi_ilo" => {
        type: "ilo",
        boot: "ilo-virtual-media",
        console: "ilo",
        deploy: "iscsi",
        inspect: "ilo",
        management: "ilo",
        power: "ilo",
        raid: "agent"
      },
      "iscsi_irmc" => {
        type: "irmc",
        boot: "irmc-virtual-media",
        deploy: "iscsi",
        inspect: "irmc",
        management: "irmc",
        power: "irmc",
        raid: "irmc"
      },
      "iscsi_pxe_oneview" => {
        type: "oneview",
        boot: "pxe",
        deploy: "oneview-iscsi",
        inspect: "oneview",
        management: "oneview",
        power: "oneview",
        raid: "agent"
      },
      "pxe_agent_cimc" => {
        type: "cisco-ucs-standalone",
        boot: "pxe",
        deploy: "direct",
        inspect: "inspector",
        management: "cimc",
        power: "cimc",
        raid: "agent"
      },
      "pxe_drac" => {
        type: "idrac",
        boot: "pxe",
        deploy: "iscsi",
        inspect: "idrac",
        management: "idrac",
        power: "idrac",
        raid: "idrac"
      },
      "pxe_drac_inspector" => {
        type: "idrac",
        boot: "pxe",
        deploy: "iscsi",
        inspect: "inspector",
        management: "idrac",
        power: "idrac",
        raid: "idrac"
      },
      "pxe_ilo" => {
        type: "ilo",
        boot: "ilo-pxe",
        console: "ilo",
        deploy: "iscsi",
        inspect: "ilo",
        management: "ilo",
        power: "ilo",
        raid: "agent"
      },
      "pxe_ipmitool" => {
        type: "ipmi",
        boot: "pxe",
        deploy: "iscsi",
        inspect: "inspector",
        management: "ipmitool",
        power: "ipmitool",
        raid: "agent"
      },
      "pxe_ipmitool_socat" => {
        type: "ipmi",
        boot: "pxe",
        console: "ipmitool-socat",
        deploy: "iscsi",
        inspect: "inspector",
        management: "ipmitool",
        power: "ipmitool",
        raid: "agent"
      },
      "pxe_iscsi_cimc" => {
        type: "cisco-ucs-standalone",
        boot: "pxe",
        deploy: "iscsi",
        inspect: "inspector",
        management: "cimc",
        power: "cimc",
        raid: "agent"
      },
      "pxe_irmc" => {
        type: "irmc",
        boot: "irmc-pxe",
        deploy: "iscsi",
        inspect: "irmc",
        management: "irmc",
        power: "irmc",
        raid: "irmc"
      },
      "pxe_snmp" => {
        type: "snmp",
        boot: "pxe",
        deploy: "iscsi",
        inspect: "no-inspect",
        management: "fake",
        power: "snmp",
        raid: "agent"
      },
      "pxe_ucs" => {
        type: "cisco-ucs-managed",
        boot: "pxe",
        deploy: "iscsi",
        inspect: "inspector",
        management: "ucsm",
        power: "ucsm",
        raid: "agent"
      }
    }
    a["enabled_drivers"].each do |driver|
      next unless mapping.key? driver
      fields.each do |field|
        next if mapping[driver][field.to_sym].nil?
        attribute = "enabled_" + (field == "type" ? "hardware_types" : "#{field}_interfaces")
        a[attribute].push(mapping[driver][field.to_sym]).uniq!
      end
    end
  end

  a.delete("enabled_drivers")

  return a, d
end

def downgrade(ta, td, a, d)
  return a, d
end
