define :devmode_converge_loop, :remote_recipe => "" do
  
  total = node[:devmode][:converge_loop][:total].to_i
  count = node[:devmode][:converge_loop][:count].to_i

  if total > 0
    TAG = "devmode:loop=#{node[:rightscale][:instance_uuid]}"
    log "Tag server for loop requests. Tag: #{TAG}"
    right_link_tag TAG
 
    log "============== Boot converge loop (#{count}/#{total}) ============="
  
    # Use remote_recipe "ping-pong" to syncronize runs 
    remote_recipe "ping-pong the running of recipe" do
      only_if do total > count end
      recipe params[:remote_recipe]
      recipients_tags TAG
    end

    # Increment loop count in node 
    node[:devmode][:converge_loop][:count] = "#{count+1}"
  end
  
end