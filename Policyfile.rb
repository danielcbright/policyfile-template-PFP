# Policyfile.rb - Describe how you want Chef Infra Client to build your system.
#
# For more information on the Policyfile feature, visit
# https://docs.chef.io/policyfile.html

# A name that describes what the system you're building with Chef does.
name 'POLICYNAME'

# Where to find external cookbooks:
default_source :supermarket

# run_list: chef-client will run these recipes in the order specified.
run_list 'POLICYNAME::default'

# Specify Base include_policy:
include_policy 'base-linux', policy_name: 'base-linux', policy_group: 'unstable', server: 'https://automate.dbright.io/organizations/dbright'
