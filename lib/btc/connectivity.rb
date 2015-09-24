require 'btc/store'
require 'btc/session'

module Btc
  module Connectivity

    private

    def session
      @session ||= (
        store = Btc::Store.new(ENV['HOME'])
        Btc::Session.new(store)
      )
    end

    def root
      @root ||= session.client.root
    end

    def shop
      root.shops.first
    end

  end
end
