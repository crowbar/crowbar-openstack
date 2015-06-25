Welcome to a Barclamp for the Crowbar Framework project
=======================================================

The code and documentation is distributed under the [Apache 2 license](http://www.apache.org/licenses/LICENSE-2.0.html).
Contributions back to the source are encouraged.

The [Crowbar Framework](https://github.com/crowbar/crowbar) was developed by the
[Dell CloudEdge Solutions Team](http://dell.com/openstack) as a [OpenStack](http://OpenStack.org) installer but has
evolved as a much broader function tool. A Barclamp is a module component that implements functionality for Crowbar.
Core barclamps operate the essential functions of the Crowbar deployment mechanics while other barclamps extend the
system for specific applications.

**This functonality of this barclamp DOES NOT stand alone, the Crowbar Framework is required**

About this barclamp
-------------------

[![Build Status](https://travis-ci.org/crowbar/barclamp-trove.svg?branch=master)](https://travis-ci.org/crowbar/barclamp-trove)
[![Code Climate](https://codeclimate.com/github/crowbar/barclamp-trove/badges/gpa.svg)](https://codeclimate.com/github/crowbar/barclamp-trove)
[![Test Coverage](https://codeclimate.com/github/crowbar/barclamp-trove/badges/coverage.svg)](https://codeclimate.com/github/crowbar/barclamp-trove)
[![Dependency Status](https://gemnasium.com/crowbar/barclamp-trove.svg)](https://gemnasium.com/crowbar/barclamp-trove)
[![Join the chat at https://gitter.im/crowbar](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/crowbar)

This barclamp uses a wrapper cookbook around an upstream/stackforge-style openstack-database-service cookbook. It
also includes two additional cookbooks: openstack-common, openstack-identity which are required for their
libraries/LWRPs, but no recipes are run from them.

Contributing
------------

This repository contains copies of upstream stackforge openstack cookbook repos from github.com/stackforge/cookbook-openstack-*
for cookbooks: common, identity and database. In order to update the code to a new upstream version, just copy the
upstream content over to our repo.

Legals
------

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
