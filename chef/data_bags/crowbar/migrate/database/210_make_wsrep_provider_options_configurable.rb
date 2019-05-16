def upgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["mysql"]["wsrep_provider_options_custom"] = template_attrs["mysql"]["wsrep_provider_options_custom"] unless attrs["mysql"]["wsrep_provider_options_custom"]
  attrs["mysql"]["gcs_fc_limit_multiplier"] = template_attrs["mysql"]["gcs_fc_limit_multiplier"] unless attrs["mysql"]["gcs_fc_limit_multiplier"]
  attrs["mysql"]["gcs_fc_factor"] = template_attrs["mysql"]["gcs_fc_factor"] unless attrs["mysql"]["gcs_fc_factor"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  attrs["mysql"].delete("wsrep_provider_options_custom") unless template_attrs["mysql"].key?("wsrep_provider_options_custom")
  attrs["mysql"].delete("gcs_fc_limit_multiplier") unless template_attrs["mysql"].key?("gcs_fc_limit_multiplier")
  attrs["mysql"].delete("gcs_fc_factor") unless template_attrs["mysql"].key?("gcs_fc_factor")
  return attrs, deployment
end
