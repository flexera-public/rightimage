#
# Cookbook Name:: remote_recipe
# Recipe:: do_tag_test
#
# Copyright 2009, RightScale, Inc.
#
# All rights reserved - Do Not Redistribute
#
COLLECTION_NAME = "tag_test"
TAG = "test:foo=bar"

log "============ resource test: right_link_tag =============="

log "Add tag: #{TAG}"
right_link_tag "#{TAG}"

log "Verify tag exists"
wait_for_tag TAG do
  collection_name COLLECTION_NAME
end

log "Remove tag: #{TAG}"
right_link_tag "test:foo=bar" do
  action :remove
end

log "Verify tag is gone"
wait_for_tag TAG do
  collection_name COLLECTION_NAME
  should_exist false
end