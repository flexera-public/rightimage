# Overview 

This project is a set of cookbooks to build and test RightImages.

# Usage

## Cookbooks

Please see the readme in the cookbooks directory for usage of the cookbooks.
There are also some helper rake tasks to help launch collateral.

## Rake tasks

### rake metadata

Rebuilds all metadata.json files with the hash keys sorted (for git merging niceness)

### rake integration_test

See the Rakefile for options. Launches an image_tester to perform integration tests
on built images for you.

Example usage:

   # Run image_tester vs softlayer clouds only
   rake integration_test st=v13 cloud_ids=1869

   # Run image_tester off head tester with custom mci
   rake integration_test mci="PS_RightImage_CentOS_6.3_x64_v5.8_Dev"

## Copyright

Copyright (c) 2013 RightScale

Maintained by the RightScale Ivory Team
