#!/usr/bin/env ruby

require 'rubygems'
# JSON not in core-ruby.
require 'json'
# Platform checking.
require 'rbconfig'

# Monkeypatch to recursively clean empty hashes.
class Hash
  def rec_delete_empty
    delete_if{|k, v| v.nil? or v.empty? or v.instance_of?(Hash) && v.rec_delete_empty.empty?}
  end
end

# JSON class infrastructure.

# Inform parser what platform file is from.
class OS
  def initialize() 
    # If it contains linux then Linux, otherwise Windows (future dev).
    if Config::CONFIG["host_os"] =~ /linux/i
      @os = "linux"
    else  
      @os = "windows"
    end 
  end

  def to_hash(*a) {"os" => @os} end
end


# Linux Standard Base.
# lsb_release: id (i), description (d), release (r), codename (c) .
class LSB
  def initialize()
    # Retrieve and split command output.
    lsb = `lsb_release -ircs`.split

    @id = lsb[0]
    # Called separately to get full description with spaces.
    # Sanitize newline and quotes.
    @description = `lsb_release -ds`.sub("\n",'').gsub("\"",'')
    @release = lsb[1]
    @codename = lsb[2]
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

# Kernel release name.
# Retrieved from /boot/grub/grub.conf if it is available.
# rec_empty_delete strips empty and nil values.
class Kern
  def initialize()
    # kernel-release is on the first line beginning with "(optional whitespace)initrd".
    # It is located after the first "-" and should not include an ending ".img", if present.
    if File.exists? "/boot/grub/grub.conf"
      @release = IO.read("/boot/grub/grub.conf").match(/^\s*initrd[^-]*-(.*)(?:.img)?$/)[1]
    else
      @release = nil
    end
  end

  def to_hash(*a)
    {"kernel" => 
      {"release" => @release}.delete_if{ |k,v| v.nil? }
    }
  end
end


# List packages on Linux system.
# Takes the LSB's id as an argument.
class Packages
  def initialize(id)
    # Prep packages hash
    packs = Hash.new

    # Linux distro family specific options:
      # Ubuntu = dpkg,
      # CentOS/RHEL = rpm,
        # or exit.
 
    case id
      when "Ubuntu"
        # Read packages into a hash.
        `dpkg-query -W`.each_line{ |line|
          col = line.split 
          packs[col[0]] = col[1]
          }

      when "CentOS", /RedHat/
        # Read packages into a hash.
        `rpm -qa --qf "%{NAME}\t%{VERSION}\n"`.each_line{ |line|
              col = line.split
              packs[col[0]] = col[1]
              }
      else
        packs["This distro"] = "is not supported."
        exit
      end

    # Store in instance variable to extract rightlink version.
    @packages = packs
  end

  def to_hash(*a)
    { "packages" => @packages }
  end
end


# Holds RS specific info.
# Takes hint hash as arg.
class RightScaleMirror
  def initialize(hint)
    @repo_freezedate = hint["freeze-date"]
    @rubygems_freezedate = hint["freeze-date"]
    @rightlink_version = hint["rightlink-version"]
  end

  def to_hash(*a)
    {"rightscale-mirror" =>
      {"repo-freezedate" => @repo_freezedate, 
      "rubygems-freezedate" => @rubygems_freezedate,
      "rightlink-version" => @rightlink_version
      }
    # Strip empty values
    }.rec_delete_empty
  end
end

# TO-DO: Arbitrary and rebundle cases.
# Holds info about the image.
# MD5 sums added to report_hash in later step.
# Takes hint hash as arg.
class Image
  def initialize(hint)
    @build_date = hint["build-date"]
  end

  def to_hash(*a)
    {"image" => 
      {"build-date" => @build_date } 
    # Delete empty pairs.
    }.rec_delete_empty
  end
end

# Name of the cloud the image is meant for.
class Cloud
  def initialize()
    # Safely ignores hint if not available.
    if File.exists? "/etc/rightscale.d/cloud"
      @cloud = File.open('/etc/rightscale.d/cloud', &:readline)
    else
      @cloud = nil
    end
  end
  # Strips value if nil.
  def to_hash(*a) {"cloud" => @cloud}.delete_if{ |k,v| v.nil? } end
end

# End JSON class infrastructure.

# Merge JSON of classes into report_hash.
report_hash = Hash.new
report_hash.merge!(OS.new)
# Switch on OS.
if report_hash["os"] != "linux"
  puts "Windows support is coming... soon."
  exit
end

# And the rest.
report_hash.merge!(LSB.new)
report_hash.merge!(Kern.new)
report_hash.merge!(Cloud.new)

# Take platform as arg.
report_hash.merge!(Packages.new(report_hash["lsb"]["id"]))

# Give hint hash.
if File.exists? "/etc/rightscale.d/rightimage-release.js"
  hint = JSON.parse(File.read('/etc/rightscale.d/rightimage-release.js'))
# Otherwise give empty hint hash.
else
  hint = Hash.new
end  
  
# Receive hint.
report_hash.merge!(RightScaleMirror.new(hint))
report_hash.merge!(Image.new(hint))

# Print results if flag is set.
if(ARGV[0] == "print" )
  puts JSON.pretty_generate(report_hash)
end

# Save JSON to /tmp.
File.open("/tmp/report.js","w") do |f|
  f.write(JSON.pretty_generate(report_hash))
end
