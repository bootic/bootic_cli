require 'thor'
require 'bootic_cli/connectivity'
require 'bootic_cli/cli'

module BooticCli
  module Commands
    class Orders < Thor
      include Thor::Actions
      include BooticCli::Connectivity

      class TableFormatter
        CELL_PADDING = 5.freeze

        def format(orders)
          data = [['status', 'updated', 'created', 'code', 'total', 'client']]
          data += orders.map do |order|
            [order.status, order.updated_on, order.created_on, order.code, order.total, order_contact_name(order)]
          end

          table data
        end

        private

        def table(array_of_arrays, headings = true)
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
            sep = cell_sizes.map{|i| '-' * (i + CELL_PADDING)}.join('-+-')
            data.insert(1, sep)
          end

          data.join("\r\n")
        end

        def order_contact_name(order)
          return '' unless order.has?(:contact)
          "#{order.contact.name} <#{order.contact.email}>"
        end

      end

      FORMATTERS = {
        'table' => TableFormatter
      }

      desc 'list', 'List shop orders'
      option :s, banner: "<status>"
      option :o, banner: "<output_format>", default: 'table'
      option :a, type: :boolean, desc: "Get full data set", default: false
      option :q, banner: "<query>"
      option :ugte, banner: "<updated_after>", desc: "Updated after, ie. 2015-10-01"
      option :ulte, banner: "<updated_before>", desc: "Updated before, ie. 2015-10-01"
      option :c, banner: "<code>"

      def list
        opts = {}
        opts[:status] = options['s'] if options['s']
        opts[:q] = options['q'] if options['q']
        opts[:updated_on_gte] = options['ugte'] if options['ugte']
        opts[:updated_on_lte] = options['ulte'] if options['ugte']
        opts[:code] = options['c'] if options['c']

        orders = shop.orders(opts)
        orders = orders.full_set if options[:a]
        formatter = FORMATTERS.fetch(options['o'], 'table')
        puts formatter.new.format(orders)

        # print_table data
        # puts JSON.dump(orders.map{|r| r.to_hash})
      end

      BooticCli::CLI.register self, 'orders', 'orders SUBCOMMAND ...ARGS', 'manage orders'
    end

  end
end
