RETURN_RECIPE = "devmode::do_converge_loop"

devmode_converge_loop RETURN_RECIPE do
  remote_recipe RETURN_RECIPE
end