require 'thread'
module BooticCli
  class WorkerPool
    def initialize(how_many)
      @how_many = how_many
      @queue = Queue.new
    end

    def schedule(&block)
      @queue.push block
    end

    def start
      threads = @how_many.times.map do |i|
        Thread.new do
          begin
            while job = @queue.pop(true)
              job.call
            end
          rescue ThreadError
          end
        end
      end
      threads.map(&:join)
    end
  end
end

