def upgrade(ta, td, a, d)
  a["manila"]["capability_storage_protocol"] = a["manila"]["storage_protocol"]
  a["manila"]["run_share_group_tests"] = a["manila"]["run_consistency_group_tests"]
  a["manila"].delete("storage_protocol")
  a["manila"].delete("run_consistency_group_tests")
  return a, d
end

def downgrade(ta, td, a, d)
  a["manila"]["storage_protocol"] = a["manila"]["capability_storage_protocol"]
  a["manila"]["run_consistency_group_tests"] = a["manila"]["run_share_group_tests"]
  a["manila"].delete("capability_storage_protocol")
  a["manila"].delete("run_share_group_tests")
  return a, d
end
