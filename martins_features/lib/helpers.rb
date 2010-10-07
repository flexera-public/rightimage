

def create_server(server_name)
  server = Server.create(:nickname => server_name , \
                         :deployment_href => @deployment.href , \
                         :server_template_href => ENV['FRONTEND_HREF'] , \
                         :ec2_image_href => ENV['IMAGE_HREF'] , \
                         :ec2_ssh_key_href => ENV['SSH_KEY_HREF'] , \
                         :cloud_id => ENV['CLOUD_ID'], \
                         :instance_type => ENV['INSTANCE_TYPE'], \
                         :ec2_security_groups_href => ENV['SECURITY_GROUP_HREF'])
  raise "could not create server" unless server
  return server
end


def find_or_create_server(server_name)
  servers = @deployment.servers_no_reload
  server = servers.select { |s| s.nickname == server_name }
  raise "found more than one server that matches '#{server_name}'" if server.size > 1
  return server if server.size == 1
  create_server(server_name)
end
