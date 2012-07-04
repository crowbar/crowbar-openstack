from nose.plugins.attrib import attr
from tempest import exceptions
from tempest import openstack
from tempest.common.utils.data_utils import rand_name
import argparse
import base64
import logging
import subprocess
import unittest2 as unittest


def get_argparser():
    parser = argparse.ArgumentParser()
    parser.add_argument('-w', dest='w_dir', help="tempest working dir")
    parser.add_argument('tests', nargs='+', help="tests to run")
    return parser


if __name__ == '__main__':
    args = get_argparser().parse_args()
    process = subprocess.Popen(['nosetests', '-q', '-w', args.w_dir,
                                " ".join(args.tests), '--with-xunit',
                                '--xunit-file=/dev/stdout'],
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
            client.wait_for_volume_status(vol['id'], 'GRRR')
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
    # Get tenant_id of current user. I know that it's very magic,
    # but I do not want to use keystone yet.
    tenant_id = os.images_client.client.base_url.split('/')[-1]
    # I have to use another client, because there is no owner parameter
    # in list in images_client
    os2 = openstack.ServiceManager()
    client = os2.images.get_client()
    images = filter(lambda image: image[u'owner'] == tenant_id,
                                        client.get_images_detailed())
    for image in images:
        if 'tempest' in image[u'name']:
            continue
        client.delete_image(image[u'id'])
#    resp, data = client.list_images()
#    print data
#    for img in data:
#        if 'tempest' in img['name']: continue
#        client.delete_image(img['id'])
    exit(process.returncode)
