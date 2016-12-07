require 'json'
require 'csv'

module BooticCli
  module Formatters

    class Table
      CELL_PADDING = 5.freeze

      def format(array_of_arrays, headings = true)
        array_of_arrays = array_of_arrays.dup

        # [122, 23, 45, 66]
        cell_sizes = array_of_arrays.each.with_object([]) do |row, memo|
          row.each.with_index do |cell, idx|
            if !memo[idx] || memo[idx] < cell.size
              memo[idx] = cell.size
            end
          end
        end

        data = array_of_arrays.map do |row|
          row.map.with_index{|e, idx|
            e.to_s.ljust(cell_sizes[idx] + CELL_PADDING)
          }.join(' | ')
        end

        if headings
          sep = cell_sizes.map{|i| '-' * (i + CELL_PADDING)}.join('-|-')
          data.insert(1, sep)
        end

        data.join("\r\n")

      end

    end

    class Json
      def format(data)
        JSON.dump data
      end
    end

    class Csv
      def format(data)
        CSV.generate do |csv|
          data.each do |row|
            csv << row
          end
        end
      end
    end

    FMTS = {
      table: Table,
      json: Json,
      csv: Csv
    }

    def self.format(k, data)
      FMTS[k.to_sym].new.format(data)
    end
  end
end
