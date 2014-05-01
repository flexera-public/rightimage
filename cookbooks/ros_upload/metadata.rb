name             'ros_upload'
maintainer       'RightScale, Inc.'
maintainer_email 'images@rightscale.com'
license          "Apache v2.0"
description      'Uploads files on disk to a remote object store. Only s3 currently supported.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

recipe "ros_upload::default", "Default recipe. Installs prerequisites."