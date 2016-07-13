# frozen_string_literal: true
name "ironic-server"
description "Ironic Server Role"
run_list("recipe[ironic::role_ironic_server]")
default_attributes
override_attributes
