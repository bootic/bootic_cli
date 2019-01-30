# Bootic CLI

CLI to interact with the [Bootic API](https://api.bootic.net/) and run custom API scripts. [Aquí hay una guía](https://github.com/bootic/bootic_cli/blob/master/GUIA.md) en castellano que explica cómo se instala y usa.

## Installation

Install via Rubygems:

    gem install bootic_cli

## Usage

    bootic help
    bootic setup
    bootic login
    bootic console

### Console

`bootic console` launches an API session into an IRB console. You'll have `root` and `shop` API entities already initialized for you.

```
> shop.orders(status: "all").each do |o|
>   puts o.total
> end

> explain shop

> list shop.products

> explain_link shop, :products
```

Access the configured client:

```
> client session.client
> new_root = client.from_url("https://some.endpoint.com")
```

### Custom scripts

You can run simple Ruby scripts in the context of an API session with

    bootic runner my_script.rb

Your script will be provided with the following variables:

```ruby
# the API root resource
root

# your default shop
shop
```

An example script that lists your shop's products:

```ruby
# list_products.rb
shop.products.full_set.each do |p|
  puts p.title
end
```

You run it with:

```
bootic runner list_products.rb
```

### Custom Thor commands

More advanced scripts can be written as [Thor]() commands. Any scripts in `~/bootic` will be loaded automatically.

```ruby
# ~/.bootic/list_products.rb
class ListProducts < BooticCli::Command

  desc "list", "list products by status"
  option :s, banner: "<status>"
  def list
    shop.products(status: options["s"]).full_set.each do |p|
      puts p.title
    end
  end
  
  declare self, "list_products"
end
```

Now `bootic help` will list your custom `list_products` command.

```
bootic help list_products

# list hidden products
bootic list_products list -s hidden
```

## Contributing

1. Fork it ( https://github.com/bootic/bootic_cli/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Copyright

(c) Bootic. Licensed under the Mozilla Public License v2.0.
