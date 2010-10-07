require 'json'

class DnsHelper
  def initialize()
     dns_file = JSON.parse File.read("dns.json")
     @dns_records = dns_file["dns_records"]
  end

  def pop
    @dns_records.pop
  end
end
