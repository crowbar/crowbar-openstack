#
# Copyright 2017, SUSE LINUX GmbH
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

default[:escm][:proxy][:no_proxy_default] = "localhost,127.0.0.1"

default[:escm][:ssl][:certfile] = "/etc/escm/ssl/certs/signing_cert.pem"
default[:escm][:ssl][:keyfile] = "/etc/escm/ssl/private/signing_key.pem"
default[:escm][:ssl][:generate_certs] = false
default[:escm][:ssl][:ca_certs] = "/etc/escm/ssl/certs/ca.pem"
