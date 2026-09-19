require 'socket'
require 'uri'

module BooticCli
  class LocalServer
    CALLBACK_PORTS = (33100..33110).freeze
    CALLBACK_HOST  = '127.0.0.1'
    CALLBACK_PATH  = '/callback'
    WAIT_TIMEOUT   = 120 # seconds

    class NoPortAvailable < StandardError; end
    class TimedOut < StandardError; end

    SUCCESS_HTML = <<~HTML.freeze
      <html>
        <head><title>Bootic CLI</title></head>
        <body style="font-family:sans-serif;text-align:center;padding:3em;color:#333">
          <h1 style="color:#2ecc71">&#10003; Authentication successful!</h1>
          <p>You can close this tab and return to the terminal.</p>
        </body>
      </html>
    HTML

    def self.callback_url(port)
      "http://localhost:#{port}#{CALLBACK_PATH}"
    end

    # Tries each port in CALLBACK_PORTS until one is free, starts a local HTTP
    # server on it, yields the port (so the caller can open the browser), then
    # blocks until the OAuth callback arrives. Returns the parsed query params.
    def self.wait_for_callback(&before_wait)
      port, server = bind_to_free_port
      raise NoPortAvailable, "Could not bind on any port in #{CALLBACK_PORTS.first}-#{CALLBACK_PORTS.last}" unless server

      before_wait.call(port) if before_wait

      begin
        raise TimedOut unless IO.select([server], nil, nil, WAIT_TIMEOUT)

        socket = server.accept
        request_line = socket.gets
        drain_headers(socket)

        params = parse_query(request_line)

        socket.print build_response(SUCCESS_HTML)
        socket.close

        params
      ensure
        server.close rescue nil
      end
    end

    def self.bind_to_free_port
      CALLBACK_PORTS.each do |port|
        server = TCPServer.new(CALLBACK_HOST, port) rescue next
        return [port, server]
      end
      [nil, nil]
    end
    private_class_method :bind_to_free_port

    def self.drain_headers(socket)
      line = socket.gets
      line = socket.gets while line && line.chomp != ''
    end
    private_class_method :drain_headers

    def self.parse_query(request_line)
      path = request_line.to_s.split(' ')[1].to_s
      query = URI.parse("http://localhost#{path}").query.to_s
      URI.decode_www_form(query).to_h
    rescue URI::InvalidURIError
      {}
    end
    private_class_method :parse_query

    def self.build_response(body)
      "HTTP/1.1 200 OK\r\n" \
        "Content-Type: text/html; charset=utf-8\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n" \
        "\r\n#{body}"
    end
    private_class_method :build_response
  end
end
