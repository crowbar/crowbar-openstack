name "monasca-metric-agent"
description "Monasca Metric Agent Role"
run_list("recipe[monasca::role_monasca_metric_agent]")
default_attributes
override_attributes
