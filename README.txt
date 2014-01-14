Welcome to a Barclamp for the Crowbar Framework project
=======================================================
_Copyright 2014, SUSE_

The code and documentation is distributed under the Apache 2 license (http://www.apache.org/licenses/LICENSE-2.0.html). Contributions back to the source are encouraged.

The Crowbar Framework (https://github.com/crowbar/crowbar) was developed by the Dell CloudEdge Solutions Team (http://dell.com/openstack) as a OpenStack installer (http://OpenStack.org) but has evolved as a much broader function tool. 
A Barclamp is a module component that implements functionality for Crowbar.  Core barclamps operate the essential functions of the Crowbar deployment mechanics while other barclamps extend the system for specific applications.

* The functionality of this barclamp DOES NOT stand alone, the Crowbar Framework is required. *


About this Barclamp: Trove
-------------------------------

TODO

Contributing
------------

This repository contains a copy of the cookbook-openstack-database_service repository which is a git subtree. Here are some useful commands to help work with it:

First add the cookbook repository as a remote:

```
$ git remote add cookbook git@github.com:mapleoin/cookbook-openstack-database_service.git
$ git fetch
```

Then add the git subtree.

```
$ git subtree add --prefix chef/cookbooks/openstack-database_service/ --squash cookbook master
```

Now you can push commits done to the upstream cookbook into that repository directly:

```
$ git subtree push --prefix=chef/cookbooks/openstack-database_service/ cookbook master
```


Legals
-------------------------------------
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
