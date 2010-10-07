# grab test source from remote repository
repo_git_pull "Get Test Repository" do
  url @node[:virtual_monkey][:code][:url]
  branch @node[:virtual_monkey][:code][:branch] 
  dest "/root/test"
  cred @node[:virtual_monkey][:code][:credentials]
end