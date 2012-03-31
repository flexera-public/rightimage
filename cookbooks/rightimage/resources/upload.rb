actions :upload

# S3 bucket and path to upload file to. If the s3_path ends in a slash it will 
# use that as a pathname and the basename of the file as the filename, else
# it will rename the file 
attribute :bucket, :kind_of => String
attribute :s3_path, :kind_of => String
# Full path to local file on disk
attribute :file, :kind_of => String

