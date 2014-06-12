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

Information for this barclamp is maintained on the [Crowbar Framework Wiki](https://github.com/crowbar/crowbar/wiki)

Data bags
---------

```
openssl rand -base64 512 | tr -d '\r\n' > /etc/chef/openstack_data_bag_secret
scp /etc/chef/openstack_data_bag_secret root@trove-api-node:/etc/chef/
export EDITOR=vi
```

```
knife data bag create secrets openstack_identity_bootstrap_token --secret-file /etc/chef/openstack_data_bag_secret
```

> {
>   "id": "openstack_identity_bootstrap_token",
>   "openstack_identity_bootstrap_token": "406356008824"
> }

```
knife data bag create db_passwords openstack-database-service --secret-file /etc/chef/openstack_data_bag_secret
```

> {
>   "openstack-database-service": "db_pass",
>   "id": "openstack-database-service"
> }

```
knife data bag create user_passwords openstack-database-service --secret-file /etc/chef/openstack_data_bag_secret 
```

> {
>   "id": "openstack-database-service",
>   "openstack-database-service": "user-pass"
> }

```
knife data bag create user_passwords guest --secret-file /etc/chef/openstack_data_bag_secret
```

> {
>   "id": "guest",
>   "guest": "guest-pass"
> }

Note: For development, you do not have to use databags and can simply set developer_mode in the default trove recipe:

```ruby
node.set[:openstack][:developer_mode] = true
```

Contributing
------------

This repository contains a copy of the cookbook-openstack-database-service repository which is a git 
subtree. Here are some useful commands to help work with it:

* First add the cookbook repository as a remote

  ```
  $ git remote add cookbook git@github.com:mapleoin/cookbook-openstack-database-service.git
  $ git fetch
  ```

* Then add the git subtree

  ```
  $ git subtree add --prefix chef/cookbooks/openstack-database-service/ --squash cookbook master
  ```

* Now you can push commits done to the upstream cookbook into that repository directly

  ```
  $ git subtree push --prefix=chef/cookbooks/openstack-database-service/ cookbook master
  ```

Legals
------

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
