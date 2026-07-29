require 'spec_helper'
require 'bootic_cli/local_server'
require 'socket'

describe BooticCli::LocalServer do
  describe '.callback_url' do
    it 'returns a localhost URL with the given port and callback path' do
      expect(described_class.callback_url(33100)).to eq('http://localhost:33100/callback')
      expect(described_class.callback_url(33105)).to eq('http://localhost:33105/callback')
    end
  end

  describe '.wait_for_callback' do
    it 'raises NoPortAvailable when all ports in the range are already bound' do
      servers = (33100..33110).map do |port|
        TCPServer.new('127.0.0.1', port) rescue nil
      end.compact

      begin
        expect {
          described_class.wait_for_callback
        }.to raise_error(BooticCli::LocalServer::NoPortAvailable)
      ensure
        servers.each { |s| s.close rescue nil }
      end
    end

    it 'yields the bound port to the block before waiting' do
      yielded_port = nil

      thread = Thread.new do
        described_class.wait_for_callback do |port|
          yielded_port = port
          # Immediately send a minimal HTTP callback so the server can exit
          begin
            s = TCPSocket.new('127.0.0.1', port)
            s.print "GET /callback?code=xyz&state=abc HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
            s.read
            s.close
          rescue
          end
        end
      end

      thread.join(5)
      expect(yielded_port).to be_between(33100, 33110)
    end

    it 'parses and returns the query params from the callback request' do
      params = nil

      described_class.wait_for_callback do |port|
        Thread.new do
          sleep 0.05
          s = TCPSocket.new('127.0.0.1', port)
          s.print "GET /callback?code=auth-code-999&state=mystate HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
          s.read
          s.close
        end
      end.tap { |p| params = p }

      expect(params['code']).to eq('auth-code-999')
      expect(params['state']).to eq('mystate')
    end

    it 'raises TimedOut when no callback arrives within the timeout' do
      original_timeout = BooticCli::LocalServer::WAIT_TIMEOUT
      stub_const('BooticCli::LocalServer::WAIT_TIMEOUT', 0.001)

      expect {
        described_class.wait_for_callback { |_port| }
      }.to raise_error(BooticCli::LocalServer::TimedOut)
    end
  end
end
