from nose.plugins.attrib import attr
from tempest import exceptions
from tempest import openstack
from tempest.common.utils.data_utils import rand_name
import base64
import logging
import subprocess
import unittest2 as unittest


if __name__ == '__main__':
    process = subprocess.Popen(['nosetests', '-q', '-w', '/opt/tempest',
                                'tempest.tests.test_authorization',
                                '--with-xunit', '--xunit-file=/dev/stdout'],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out, err = process.communicate()
    print out
    logging.basicConfig()
    logging.disable('ERROR')
    os = openstack.Manager()
    client = os.floating_ips_client
    resp, data = client.list_floating_ips()
    #TODO:agordeev
    #take care of response statuses
    for ip in data:
        if ip['instance_id']:
            client.disassociate_floating_ip_from_server(ip['ip'],
                                                        ip['instance_id'])
        client.delete_floating_ip(ip['id'])
    client = os.volumes_client
    resp, data = client.list_volumes()
    for vol in data:
        if vol['status'] in ('error', 'available'):
            client.delete_volume(vol['id'])
        try:
            client.wait_for_volume_status(vol['id'],'GRRR')
        except exceptions.NotFound:
            pass
    client = os.servers_client
    resp, data = client.list_servers()
    for server in data['servers']:
        client.delete_server(server['id'])
        try:
            client.wait_for_server_status(server['id'], 'GRRR')
        except exceptions.NotFound:
            pass
    client = os.security_groups_client
    resp, data = client.list_security_groups()
    for sg in data:
        client.delete_security_group(sg['id'])
    client = os.keypairs_client
    resp, data = client.list_keypairs()
    for kp in data:
        client.delete_keypair(kp['keypair']['name'])
    client = os.images_client
#    resp, data = client.list_images()
#    print data
#    for img in data:
#        if 'tempest' in img['name']: continue
#        client.delete_image(img['id'])
