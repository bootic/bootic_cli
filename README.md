# Bootic CLI

CLI to interact with the [Bootic.net API](https://developers.bootic.net/) and run custom API scripts.

## Installation

Install in your system.

```
gem install bootic_cli
```

## Usage

```
btc help
btc login
btc console
```

### Custom scripts

You can run simple Ruby scripts in the context of an API session with

```
btc runner my_script.rb
```

Your script will be provided with the following variables

```ruby
# the API root resource
root

# your default shop
shop
```

An example script that lists your shop's products

```ruby
# list_products.rb
shop.products.full_set.each do |pr|
  puts pr.title
end
```

You run it with

```
btc runner list_products.rb
```

### Custom Thor commands

More advanced scripts can be written as [Thor]() commands. Any scripts in `~/btc` will be loaded automatically.

```ruby
# ~/btc/list_products
class ListProducts < BooticCli::Command
  desc "list", "list products by status"
  option :s, banner: "<status>"
  def list
	shop.products(status: options["s"]).full_set.each do |pr|
  		puts pr.title
	end
  end
end
```

Now `btc help` will list your custom `list_products` command.

```
btc help list_products

# list hidden products
btc list_products list -s hidden
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment. Run `bundle exec btc` to use the code located in this directory, ignoring other installed copies of this gem.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/btc/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
