#
# Copyright 2019, SUSE LINUX Products GmbH
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

require 'openssl'

class OctaviaService < OpenstackServiceObject
  def initialize(thelogger = nil)
    super(thelogger)
    @bc_name = "octavia"
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
    def role_constraints
      {
        "octavia-api" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "octavia-health-manager" => {
          "unique" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "octavia-housekeeping" => {
          "unique" => false,
          "count" => 1,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        },
        "octavia-worker" => {
          "unique" => false,
          "exclude_platform" => {
            "suse" => "< 12.4",
            "windows" => "/.*/"
          },
          "cluster" => true
        }
      }
    end
  end

  def proposal_dependencies(role)
    answer = []
    answer << {
      "barclamp" => "nova",
      "inst" => role.default_attributes["octavia"]["nova_instance"]
    }
    answer << {
      "barclamp" => "neutron",
      "inst" => role.default_attributes["octavia"]["neutron_instance"]
    }
    answer << {
      "barclamp" => "barbican",
      "inst" => role.default_attributes["octavia"]["barbican_instance"]
    }
    answer << {
      "barclamp" => "keystone",
      "inst" => role.default_attributes["octavia"]["keystone_instance"]
    }
    answer << {
      "barclamp" => "glance",
      "inst" => role.default_attributes["octavia"]["glance_instance"]
    }
    answer
  end

  def create_certs(certs, nodes)
    cert_path = "/tmp/octavia"

    `rm -rf #{cert_path} 2>/dev/null`
    `mkdir #{cert_path} 2>/dev/null`

    conf=%{
    [ ca ]
    default_ca = CA_default

    [ CA_default ]
    # Directory and file locations.
    dir               = ./
    certs             = $dir/certs
    crl_dir           = $dir/crl
    new_certs_dir     = $dir/newcerts
    database          = $dir/index.txt
    serial            = $dir/serial
    RANDFILE          = $dir/private/.rand

    # The root key and root certificate.
    private_key       = $dir/private/ca.key.pem
    certificate       = $dir/certs/ca.cert.pem

    # For certificate revocation lists.
    crlnumber         = $dir/crlnumber
    crl               = $dir/crl/ca.crl.pem
    crl_extensions    = crl_ext
    default_crl_days  = 30

    # SHA-1 is deprecated, so use SHA-2 instead.
    default_md        = sha256

    name_opt          = ca_default
    cert_opt          = ca_default
    default_days      = 3650
    preserve          = no
    policy            = policy_strict

    [ policy_strict ]
    # The root CA should only sign intermediate certificates that match.
    # See the POLICY FORMAT section of `man ca`.
    countryName             = match
    stateOrProvinceName     = match
    organizationName        = match
    organizationalUnitName  = optional
    commonName              = supplied
    emailAddress            = optional

    [ req ]
    # Options for the `req` tool (`man req`).
    default_bits        = 2048
    distinguished_name  = req_distinguished_name
    string_mask         = utf8only

    # SHA-1 is deprecated, so use SHA-2 instead.
    default_md          = sha256

    # Extension to add when the -x509 option is used.
    x509_extensions     = v3_ca

    [ req_distinguished_name ]
    # See <https://en.wikipedia.org/wiki/Certificate_signing_request>.
    countryName                     = Country Name (2 letter code)
    stateOrProvinceName             = State or Province Name
    localityName                    = Locality Name
    0.organizationName              = Organization Name
    organizationalUnitName          = Organizational Unit Name
    commonName                      = Common Name
    emailAddress                    = Email Address

    # Optionally, specify some defaults.
    countryName_default             =
    stateOrProvinceName_default     =
    localityName_default            =
    0.organizationName_default      = OpenStack
    organizationalUnitName_default  = Octavia
    emailAddress_default            =
    commonName_default              =

    [ v3_ca ]
    # Extensions for a typical CA (`man x509v3_config`).
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid:always,issuer
    basicConstraints = critical, CA:true
    keyUsage = critical, digitalSignature, cRLSign, keyCertSign

    [ usr_cert ]
    # Extensions for client certificates (`man x509v3_config`).
    basicConstraints = CA:FALSE
    nsCertType = client, email
    nsComment = \"OpenSSL Generated Client Certificate\"
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid,issuer
    keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
    extendedKeyUsage = clientAuth, emailProtection

    [ server_cert ]
    # Extensions for server certificates (`man x509v3_config`).
    basicConstraints = CA:FALSE
    nsCertType = server
    nsComment = \"OpenSSL Generated Server Certificate\"
    subjectKeyIdentifier = hash
    authorityKeyIdentifier = keyid,issuer:always
    keyUsage = critical, digitalSignature, keyEncipherment
    extendedKeyUsage = serverAuth

    [ crl_ext ]
    # Extension for CRLs (`man x509v3_config`).
    authorityKeyIdentifier=keyid:always
    }

    create_ca_certificates = %{
    subj="/C=#{certs[:country]}/ST=#{certs[:province]}/L=Octavia/O=Home/CN=#{certs[:domain]}"
    pass="#{certs[:passphrase]}"
    cert_path="#{cert_path}"

    # Make directories for the two certificate authorities.
    cd $cert_path
    mkdir client_ca
    mkdir server_ca

    # Starting with the server certificate authority, prepare the CA.
    cd server_ca
    mkdir certs crl newcerts private
    chmod 700 private
    touch index.txt
    echo 1000 > serial

    # Create the server CA key.
    openssl genrsa -aes256 -out private/ca.key.pem -passout pass:$pass 4096
    chmod 400 private/ca.key.pem

    # Create the server CA certificate.
    openssl req -config ../openssl.cnf -key private/ca.key.pem -new -x509 -days 7300 -sha256 \
    -subj \"$subj\" -passin pass:$pass -extensions v3_ca -out certs/ca.cert.pem

    # Moving to the client certificate authority, prepare the CA.
    cd ../client_ca
    mkdir certs crl csr newcerts private
    chmod 700 private
    touch index.txt
    echo 1000 > serial

    # Create the client CA key.
    openssl genrsa -aes256 -out private/ca.key.pem -passout pass:$pass 4096
    chmod 400 private/ca.key.pem

    # Create the client CA certificate.
    openssl req -config ../openssl.cnf -key private/ca.key.pem -new -x509 -days 7300 -sha256 \
    -subj \"$subj\" -passin pass:$pass -extensions v3_ca -out certs/ca.cert.pem

    # Create a key for the client certificate to use.
    openssl genrsa -aes256 -out private/client.key.pem -passout pass:$pass 2048

    #Create the certificate request for the client certificate used on the controllers.
    openssl req -config ../openssl.cnf -new -sha256 -key private/client.key.pem \
    -subj "$subj" -passin pass:$pass -extensions v3_ca -out csr/client.csr.pem

    # Sign the client certificate request.
    openssl ca  -batch -config ../openssl.cnf -extensions usr_cert -days 7300 -notext -md sha256 \
    -in csr/client.csr.pem -passin pass:$pass -out certs/client.cert.pem

    # Create a concatenated client certificate and key file.
    openssl rsa -in private/client.key.pem -passin pass:$pass -out private/client.cert-and-key.pem
    cat certs/client.cert.pem >> private/client.cert-and-key.pem
    }

    File.write("#{cert_path}/openssl.cnf", conf)
    `#{create_ca_certificates}`

    nodes.each { |node|
      `sudo ssh root@#{node} mkdir /etc/octavia`
      `sudo ssh root@#{node} mkdir /etc/octavia/certs`
      `sudo rsync -rv #{cert_path}/* root@#{node}:/etc/octavia/certs`
    }

  end

  def save_proposal!(prop, options = {})
    super(prop, options)
  end


  def validate_proposal_after_save(proposal)
    #TODO: Validate that the subject for CA certificates hasn't changed
  end

  def create_proposal
    base = super

    nodes = NodeObject.all
    nodes.delete_if { |n| n.nil? || n.admin? }

    base["attributes"][@bc_name]["nova_instance"] = find_dep_proposal("nova")
    base["attributes"][@bc_name]["neutron_instance"] = find_dep_proposal("neutron")
    base["attributes"][@bc_name]["barbican_instance"] = find_dep_proposal("barbican")
    base["attributes"][@bc_name]["keystone_instance"] = find_dep_proposal("keystone")
    base["attributes"][@bc_name]["glance_instance"] = find_dep_proposal("glance")

    controller_nodes = nodes.select { |n| n.intended_role == "controller" }
    controller_node = controller_nodes.first
    controller_node ||= nodes.first

    unless nodes.nil? || nodes.length.zero?
      base["deployment"]["octavia"]["elements"] = {
        "octavia-api" => [controller_node[:fqdn]],
        "octavia-health-manager" => [controller_node[:fqdn]],
        "octavia-housekeeping" => [controller_node[:fqdn]],
        "octavia-worker" => [controller_node[:fqdn]] #TODO: controller_nodes.map(&:name)
      }
    end

    base["attributes"][@bc_name][:db][:password] = random_password
    base["attributes"][@bc_name][:health_manager][:heartbeat_key] = random_password
    base["attributes"][@bc_name][:service_password] = random_password
    base["attributes"][@bc_name][:certs][:passphrase] = random_password

    base
  end


  def apply_role_pre_chef_call(old_role, role, all_nodes)
    if old_role.nil?
      octavia_nodes = []

      all_nodes.each do |n|
        node = NodeObject.find_by_name(n)
        unless node[:keystone].nil?
          octavia_nodes << n
        end
      end

      create_certs( role.default_attributes["octavia"]["certs"], octavia_nodes.uniq)
    end

    @logger.debug("octavia apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty?

    vip_networks = ["admin", "public"]

    server_elements, server_nodes, ha_enabled = role_expand_elements(role, "octavia-api")
    reset_sync_marks_on_clusters_founders(server_elements)
    Openstack::HA.set_controller_role(server_nodes) if ha_enabled

    role.save if prepare_role_for_ha_with_haproxy(role, ["octavia", "ha", "enabled"],
                                                  ha_enabled, server_elements, vip_networks)

    net_svc = NetworkService.new @logger
    # All nodes must have a public IP, even if part of a cluster; otherwise
    # the VIP can't be moved to the nodes
    server_nodes.each do |n|
      net_svc.allocate_ip "default", "public", "host", n
    end

    allocate_virtual_ips_for_any_cluster_in_networks(server_elements, vip_networks)

    @logger.debug("octavia apply_role_pre_chef_call: leaving")
  end
end
