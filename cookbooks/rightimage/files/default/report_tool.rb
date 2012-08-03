#!/usr/bin/env ruby

# Used to silence ouput
#STDERR.reopen("quer_err.log", "w")

require 'rubygems'
#JSON not in core-ruby
require 'json'
#Platform checking
require 'rbconfig'

# Monkeypatch to recursively clean empty hashes
class Hash
  def rec_delete_empty
    delete_if{|k, v| v.nil? or v.empty? or v.instance_of?(Hash) && v.rec_delete_empty.empty?}
  end
end

# JSON class infrastructure

# Inform parser what platform file is from.
class OS
  def initialize() 
    # If it contains linux the Linux, otherwise Windows (in case of RS)
    if Config::CONFIG["host_os"] =~ /linux/i
      @os = "linux"
    else  
      @os = "windows"
    end 
  end
  # Refactoring idea
  #def ==(string) self.os2 == string end
  def to_hash(*a) {"os" => @os} end
end

# Linux Standard Base
# lsb_release: id (i), description (d), release (r), codename (c)
class LSB
  #attr_reader :id
  def initialize()
    # Retrieve and split command output.
    lsb = `lsb_release -ircs`.split

    @id = lsb[0]
    # Done to get full description with spaces.
    # Sanitize newline and quotes.
    @description = `lsb_release -ds`.sub("\n",'').gsub("\"",'')
    @release = lsb[2]
    @codename = lsb[1]
  end

  def to_hash(*a)
    { "lsb" =>
      {"id" => @id,
       "description" => @description,
       "release" => @release,
       "codename" => @codename} 
    }
  end
end


#uname: release (r), version (v)
class UKernel
  def initialize()
    # Sanitize newlines.
    @release = `uname -r`.sub("\n",'')
    @version = `uname -v`.sub("\n",'')
  end

  def to_hash(*a)
    {"kernel" => 
      {"release" => @release,
       "version" => @version} 
    }
  end
end


# List packages on Linux system.
# Takes the LSB's id as an argument.
class Packages
  def initialize(id)
    # Prep packages hash
    packs = Hash.new

    # Linux distro family specific options
    # 1. Parsing dpkg/yum
      # or exit

    if id == "Ubuntu"
      # Read packages into a hash
      `dpkg -l`.sub(/.*?(?=ii)/im,'').each_line{ |line|
        col = line.split[1..2] 
        packs[col[0]] = col[1]
        }

    elsif id == "CentOS" || id == "RedHatEnterpriseServer"
      # Read packages into a hash
      `rpm -qa --qf "%{NAME}\t%{VERSION}\n"`.each_line{ |line|
            col = line.split
            packs[col[0]] = col[1]
            }
    else
      packs["This platform"] = "is not supported."
      exit
    end

    # Store in instance variable
    @packages = packs
  end

  def to_hash(*a)
    { "packages" => @packages }
  end
end


# Holds RS specific info
# Takes RightLink version as an arg (even if nil)
class RightScale
  def initialize(hint)
    @repo_freezedate = hint["timestamp"]
    @rubygems_freezedate = hint["timestamp"]
    @rightlink_version = hint["rl-version"]
  end

  def to_hash(*a)
    {"rightscale" =>
      {"repo-freezedate" => @repo_freezedate, 
      "rubygems-freezedate" => @rubygems_freezedate,
      "rightlink-version" => @rightlink_version
      }
    # Delete empty pairs
    }.rec_delete_empty
  end
end

# TO-DO: Arbitrary and rebundle cases
# Holds info about the image
# MD5 sums added to blob in later step
class Image
  def initialize(hint)
    @build_date = hint["build-date"]
  end

  def to_hash(*a)
    {"image" => 
      {"build-date" => @build_date } 
    # Delete empty pairs
    }.rec_delete_empty
  end
end

# Name of the cloud the image is meant for
class Cloud
  def initialize()
    if File.exists? "/etc/rightscale.d/cloud"
      @cloud = File.open('/etc/rightscale.d/cloud', &:readline)
    else
      @cloud = nil
    end
  end
  def to_hash(*a) {"cloud" => @cloud}.delete_if{ |k,v| v.nil? } end
end

# End JSON class infrastructure

# Merge JSON of classes into blob
blob = Hash.new
blob.merge!(OS.new)
# Switch on OS
if blob["os"] != "linux"
  puts "Windows support is coming... soon."
  exit
end

# And the rest
blob.merge!(LSB.new)
blob.merge!(UKernel.new)
blob.merge!(Cloud.new)
# Take platform as arg
blob.merge!(Packages.new(blob["lsb"]["id"]))

# Give hint
if File.exists? "/etc/rightscale.d/rightimage-release.js"
  hint = JSON.parse(File.read('/etc/rightscale.d/rightimage-release.js'))
else
  hint = Hash.new
end  
# Add to hint to simplify arguments
hint["rl-version"] = blob["packages"]["rightscale"]
  
# Receive hint
blob.merge!(RightScale.new(hint))
blob.merge!(Image.new(hint))

# Print results
if(ARGV[0] == "print" )
  puts JSON.pretty_generate(blob)
end

# Save JSON to /tmp
File.open("/tmp/report.js","w") do |f|
  f.write(JSON.pretty_generate(blob))
end
