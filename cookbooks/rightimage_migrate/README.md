# DESCRIPTION:

This cookbook migrates EC2 S3 and EBS images from one region to another. It can be launched in any region.

# USAGE:

ServerTemplate: 

Use the latest version of right_image_migrator which only contains this cookbook. The default recipe will migrate the image.

## Inputs:

See metadata.rb

# Limitations

* If you migrate a public image in RightScale, you can't see it in the dash until 
you first make it private then make it public again via the RightScale dash.


# Maintainer

Maintained by the RightScale Ivory Team
email: ivory.sprint@rightscale.com
