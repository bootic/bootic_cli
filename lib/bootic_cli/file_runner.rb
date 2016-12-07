module BooticCli
  class FileRunner
    include BooticCli::Connectivity

    def initialize(root, file_name)
      @root = root
      @file_name = file_name
    end

    def run
      self.instance_eval File.read(@file_name), @file_name
    end
  end
end
