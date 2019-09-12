require 'net/http'

module BooticCli
  module Utils
    REQUEST_OPTS = {
      open_timeout: 5,
      read_timeout: 5
    }.freeze

    MAX_FETCH_ATTEMPTS = 3

    def self.fetch_http_file(href, attempt: 1, skip_verify: false)
      uri = URI.parse(href)
      opts = REQUEST_OPTS.merge({
        verify_mode: skip_verify ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER,
        use_ssl: uri.port == 443
      })

      Net::HTTP.start(uri.host, uri.port, opts) do |http|
        resp = http.get(uri.path)
        raise "Invalid response: #{resp.code}" unless resp.code.to_i == 200
        StringIO.new(resp.body)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise if attempt > MAX_FETCH_ATTEMPTS # max attempts
      # puts "#{e.class} for #{File.basename(uri.path)}! Retrying request..."
      fetch_http_file(href, attempt: attempt + 1)
    rescue OpenSSL::SSL::SSLError => e
      # retry but skipping verification
      fetch_http_file(href, attempt: attempt + 1, skip_verify: true)
    end
  end
end
