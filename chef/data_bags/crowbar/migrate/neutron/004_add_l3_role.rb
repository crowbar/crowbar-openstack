def upgrade ta, td, a, d
  unless d['elements']['neutron-server'].nil?
    d['elements']['neutron-l3'] = d['elements']['neutron-server']
  end
  d['element_states'] = td['element_states']
  d['element_order'] = td['element_order']
  d['element_run_list_order'] = td['element_run_list_order']
  return a, d
end

def downgrade ta, td, a, d
  d['element_states'] = td['element_states']
  d['element_order'] = td['element_order']
  d['elements'].delete('neutron-l3')
  d.delete('element_run_list_order')
  return a, d
end
