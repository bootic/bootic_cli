module BooticCli
  class FileRunner
    include BooticCli::Connectivity

    def self.run(root, file_name)
      new(root, file_name).run
    end

    def initialize(root, file_name)
      @root = root
      @file_name = file_name
    end

    def run
      self.instance_eval File.read(@file_name), @file_name
    end

    # #root is already defined in Connectivity
    # but we want to pass a pre-initialized root
    # to avoid having to re-fetch root from API
    def root
      @root
    end
  end
end
