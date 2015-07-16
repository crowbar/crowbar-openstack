def upgrade ta, td, a, d
  unless d['elements']['neutron-server'].nil?
    d['elements']['neutron-l3'] = d['elements']['neutron-server']
  end
  d['element_states'] = td['element_states']
  d['element_order'] = td['element_order']
  d['element_run_list_order'] = td['element_run_list_order']

  # Make sure that all nodes that have the "neutron-server" role
  # in their run_list (should only be one as we didn't support
  # HA before this schema revision) also get the "neutron-l3"
  # role added to continue to work as before.
  nodes = NodeObject.find('roles:neutron-server')
  nodes.each do |node|
    node.add_to_run_list('neutron-l3',
                         td['element_run_list_order']['neutron-l3'],
                         td['element_states']['neutron-l3'])
    node.save
  end

  return a, d
end

def downgrade ta, td, a, d
  d['element_states'] = td['element_states']
  d['element_order'] = td['element_order']
  d['elements'].delete('neutron-l3')
  d.delete('element_run_list_order')

  # Remove the neutron-l3 role from the run_list of all nodes when downgrading.
  # This is about the best we can to for the downgrade scenario. Though it only
  # works correctly when downgrading a setup where neutron-server and
  # neutron-l3 are running on the same host. Adding the neutron-server role to
  # the nodes that had neutron-l3 previously would result in multiple hosts
  # having neutron-server assigned (which is something we don't support
  # especially when downgrading to the old schema revision).
  nodes = NodeObject.find('roles:neutron-l3')
  nodes.each do |node|
    node.delete_from_run_list('neutron-l3')
    node.save
  end

  return a, d
end
