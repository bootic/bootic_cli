require 'fileutils'
require 'pstore'

module Btc

  class Store

    DIRNAME = '.btc'.freeze
    FILE_NAME = 'store.pstore'.freeze

    def initialize(base_dir = ENV['HOME'], dir = DIRNAME)
      @base_dir = File.join(base_dir, dir)
      FileUtils.mkdir_p @base_dir
    end

    def []=(k, v)
      store[k] = v
    end

    def [](k)
      store[k]
    end

    def transaction(&block)
      store.transaction(&block)
    end

    private

    attr_reader :base_dir

    def store
      @store ||= PStore.new(File.join(base_dir, FILE_NAME))
    end
  end

end
