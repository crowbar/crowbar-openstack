def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs[:elasticsearch][:tunables][:limit_nproc] = attrs[:elasticsearch][:tunables][:max_procs]
  attrs[:elasticsearch][:tunables][:limit_nofile] = attrs[:elasticsearch][:tunables][:max_open_files_hard_limit]
  attrs[:elasticsearch][:tunables][:limit_memlock] = attrs[:elasticsearch][:tunables][:max_locked_memory]
  attrs[:elasticsearch][:tunables].delete("max_procs")
  attrs[:elasticsearch][:tunables].delete("max_open_files_hard_limit")
  attrs[:elasticsearch][:tunables].delete("max_locked_memory")
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs[:elasticsearch][:tunables][:max_procs] = attrs[:elasticsearch][:tunables][:limit_nproc]
  attrs[:elasticsearch][:tunables][:max_open_files_hard_limit] = attrs[:elasticsearch][:tunables][:limit_nofile]
  attrs[:elasticsearch][:tunables][:max_locked_memory] = attrs[:elasticsearch][:tunables][:limit_memlock]
  attrs[:elasticsearch][:tunables].delete("limit_nproc")
  attrs[:elasticsearch][:tunables].delete("limit_nofile")
  attrs[:elasticsearch][:tunables].delete("limit_memlock")
  return attrs, deployment
end
