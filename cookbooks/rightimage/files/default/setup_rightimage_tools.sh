#!/bin/bash -ex
cd /tmp/rightimage_tools 
tar zxf rightimage_tools.tar.gz
gem install bundler --no-rdoc --no-ri
# Use --deployment flag so no gems are installed to system, we want to keep
# this isolated, especially in the loopback fs.  Private refers to github
# only gems.  
bundle check || bundle install --deployment --without private development