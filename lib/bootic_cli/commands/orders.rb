module BooticCli
  module Commands
    class Orders < BooticCli::Command
      class OrdersTable
        def self.call(orders)
          new(orders).data
        end

        def initialize(orders)
          @orders = orders
        end

        def data
          data = [['status', 'updated', 'created', 'code', 'total', 'discount', 'payment', 'client']]
          data += orders.map do |order|
            [order.status, order.updated_on, order.created_on, order.code, order.total, discount_line(order), payment_line(order), order_contact_name(order)]
          end
          data
        end

        private
        attr_reader :orders

        def order_contact_name(order)
          return '' unless order.has?(:contact)
          "#{order.contact.name} <#{order.contact.email}>"
        end

        def discount_line(order)
          order.discount_total > 0 ? "#{order.discount_total} (#{order.discount_name})" : ''
        end

        def payment_line(order)
          order.has?(:payment_info) ? order.payment_info.name : ''
        end
      end

      MAPPERS = {
        'table' => OrdersTable,
        'csv' => OrdersTable,
        'json' => ->(orders) { orders.to_hash }
      }

      desc 'list', 'List shop orders'
      option :s, banner: "<status>"
      option :o, banner: "<output_format>", default: 'table'
      option :a, type: :boolean, desc: "Get full data set", default: false
      option :q, banner: "<query>"
      option :so, banner: "<sort>"
      option :ugte, banner: "<updated_after>", desc: "Updated after, ie. 2015-10-01"
      option :ulte, banner: "<updated_before>", desc: "Updated before, ie. 2015-10-01"
      option :dgte, banner: "<discount_greater_than>", desc: "Discount greater than, ie. 10000"
      option :dlte, banner: "<discount_less_than>", desc: "Discount less than, ie. 20000"
      option :tgte, banner: "<total_greater_than>", desc: "Total greather than, ie. 23000"
      option :tlte, banner: "<total_less_than>", desc: "Total less than, ie. 23000"
      option :c, banner: "<code>"

      def list
        logged_in_action do
          opts = {}
          opts[:status] = options['s'] if options['s']
          opts[:q] = options['q'] if options['q']
          opts[:sort] = options['so'] if options['so']
          opts[:updated_on_gte] = options['ugte'] if options['ugte']
          opts[:updated_on_lte] = options['ulte'] if options['ugte']
          opts[:total_gte] = options['tgte'] if options['tgte']
          opts[:total_lte] = options['tlte'] if options['tlte']
          opts[:discount_total_gte] = options['dgte'] if options['dgte']
          opts[:discount_total_lte] = options['dlte'] if options['dlte']
          opts[:code] = options['c'] if options['c']

          orders = shop.orders(opts)
          orders = orders.full_set if options[:a]
          puts Formatters.format(options['o'], MAPPERS[options['o']].call(orders))
        end
      end

      declare self, "Manage shop orders"
    end
  end
end
