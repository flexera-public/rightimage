# DESCRIPTION
This is an automated integration test site for cloud images.  See individual recipes to see what is tested.

# REQUIREMENTS
This cookbook depends on the rightscale_volume and marker recipes in https://github.com/rightscale-cookbooks

# ATTRIBUTES
aws_access_key_id, aws_secret_access_key - Does a search to make sure these credentials aren't accidentally inserted in the image
root_size - Expected root volume size.  Defaults to 10GB 
test_ipv6 - Verify ipv6 is disabled
test_ssh_security - Verify root login is disabled

# USAGE
Create a servertemplate and add all recipes.  Ordering doesn't matter.

