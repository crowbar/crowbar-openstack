# Copyright 2017 FUJITSU LIMITED

name "monasca-log-agent"
description "Monasca Log Agent Role"
run_list("recipe[monasca::role_monasca_log_agent]")
default_attributes
override_attributes
