# This is part of the breakpoint test.
# if the breakpoint is working this recipe will never be executed.

ruby_block "I fail" do
  not_if do node[:devmode_test][:disable_breakpoint_test] end
  block do
    raise "ERROR: If you intended to set a breakpoint -- it failed."
  end
end