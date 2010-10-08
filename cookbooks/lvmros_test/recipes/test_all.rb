#
# Cookbook Name:: backup_test
# Recipe:: test_all
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
include_recipe "lvmros_test::test_s3"
include_recipe "lvmros_test::test_cloudfiles"