
require 'lib/cuke_monk'

cm = CukeMonk.new()

job_addrs = []
job_addrs <<  cm.run_test("foo","--tags @foo /tmp/cuke")
job_addrs <<  cm.run_test("foo2","--tags @foo2 /tmp/cuke")
job_addrs <<  cm.run_test("foo3","/tmp/cuke/martin.feature")



threads = []
job_addrs.each { |j| threads << j[0] }
cm.join(threads)

cm.generate_reports job_addrs
