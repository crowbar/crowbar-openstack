Chef cookbook for gathering SES configuration data needed to setup SOC
======================================================================


DESCRIPTION
--------

A Cloud admin can successfully connect the OpenStack cloud to a preconfigured SES storage using an exported SES configuration file without having to manually enter the configuration data.

What is needed for crowbar's SES integration at a high level.

1) read in the SES yaml file that describes the SES cluster

2) install all SES/ceph dependencies on nova, cinder, glance nodes

3) generate and install ceph.conf on nova/cinder/glance nodes

4) generate and install keyring files on nova/cinder/glance nodes

5) update the cinder, nova, glance configuration files with required ceph backend information

6) create libvirt private auth for ceph

7) update the keystone database to point to the radowsgw url for swift API

REQUIREMENTS
--------

Platform
--------

Cookbooks
---------

ATTRIBUTES
--------

TEMPLATES
--------

USAGE
--------


LICENSE AND AUTHORS
--------

* Author: Charles Wang <cwang@suse.com>

* Copyright 2018 SUSE LLC 

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
