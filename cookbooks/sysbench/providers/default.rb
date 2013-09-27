require 'mixlib/shellout'

class Chef::Provider
  include Chef::Mixin::ShellOut
end

def parse_key(text, key)
  text.split("\n").each do |line|
    if line =~ /#{key}:\s*([0-9\.\/]+(ms|s|us|))$/
      return $1
    end
  end
  raise "Could not parse out #{key} from text"
end

def parse_throughput(text)
  text.split("\n").each do |line|
    if line =~ / transferred ([^\s]+\s+)?\((.*)\)/i
      return $2
    end
  end
  raise "Could not parse out throughput from text"
end

def parse_cmd(collected_results, section, cmd)
  Chef::Log.info("Running #{cmd}")
  cmdout = shell_out!(cmd).stdout
  collected_results[section] ||= {}
  collected_results[section]["cmd"] = cmd
  collected_results[section]["output"] = cmdout
  yield(cmdout, collected_results[section])
end

action :run do
  r = new_resource
  if !::File.exists?(r.result_file)
    shell_out!("sysbench --test=fileio prepare")
    shell_out!("sync")
    # Clean out in-memory caches
    shell_out!("echo 3 > /proc/sys/vm/drop_caches")

    collected_results = {}

    parse_cmd(collected_results, "disk", "sysbench --test=fileio --file-test-mode=rndrw run") do |cmd_out, result_hash|
      result_hash["total time"] = parse_key(cmd_out, "total time")
      result_hash["throughput"] = parse_throughput(cmd_out)
    end

    parse_cmd(collected_results, "cpu", "sysbench --num-threads=4 --test=cpu run") do |cmd_out, result_hash|
      result_hash["total time"] = parse_key(cmd_out, "total time")
    end

    parse_cmd(collected_results, "memory", "sysbench --num-threads=4 --test=memory --memory-total-size=10G run") do |cmd_out, result_hash|
      result_hash["total time"] = parse_key(cmd_out, "total time")
      result_hash["throughput"] = parse_throughput(cmd_out)
    end

    parse_cmd(collected_results, "threads", "sysbench --num-threads=4 --test=threads run") do |cmd_out, result_hash|
      result_hash["total time"] = parse_key(cmd_out, "total time")
    end

    parse_cmd(collected_results, "mutex", "sysbench --num-threads=4 --test=mutex run") do |cmd_out, result_hash|
      result_hash["total time"] = parse_key(cmd_out, "total time")
    end

    mysql_db=r.mysql_db
    mysql_user=r.mysql_user
    mysql_pass=r.mysql_password
    shell_out("sysbench --test=oltp --oltp-table-size=1000000 --mysql-db=#{mysql_db} --mysql-user=#{mysql_user} --mysql-password=#{mysql_pass} prepare")
    shell_out!("sync")
    # Clean out in-memory caches
    shell_out!("echo 3 > /proc/sys/vm/drop_caches")
    parse_cmd(collected_results, "oltp", "sysbench --test=oltp --oltp-table-size=1000000 --mysql-db=#{mysql_db} --mysql-user=#{mysql_user} --mysql-password=#{mysql_pass} --max-time=60 --oltp-read-only=on --max-requests=0 --num-threads=4 run") do |cmd_out, result_hash|
      result_hash["total time"] = parse_key(cmd_out, "total time")
      result_hash["throughput"] = parse_key(cmd_out, "read/write requests")
    end

    ::File.open(r.result_file, "w") {|f| f.write(JSON.pretty_generate(collected_results))}
  end
end

