# Bootic CLI

CLI to interact with the [Bootic.net API](https://developers.bootic.net/) and run custom API scripts.

## Installation

Install in your system.

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

More advanced scripts can be written as [Thor]() commands. Any scripts in `~/.bootic` will be loaded automatically.

```ruby
# ~/.bootic/list_products
class ListProducts < BooticCli::Command

  desc "list", "list products by status"
  option :s, banner: "<status>"
  def list
    shop.products(status: options["s"]).full_set.each do |p|
      puts p.title
    end
  end

end
```

Now `bootic help` will list your custom `list_products` command.

```
bootic help list_products

# list hidden products
bootic list_products list -s hidden
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec bootic` to use the code located in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/bootic/bootic_cli/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
