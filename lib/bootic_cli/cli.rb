frequire 'thor'
require 'bootic_cli/version'
require 'bootic_cli/connectivity'
require 'bootic_cli/formatters'

module BooticCli

  DEFAULT_ENV = 'production'.freeze

  class CLI < Thor
    include Thor::Actions
    include BooticCli::Connectivity

    CUSTOM_COMMANDS_DIR = ENV.fetch("BTC_CUSTOM_COMMANDS_PATH") { File.join(ENV["HOME"], "btc") }

    package_name "Bootic CLI"

    map %w[--version -v] => :__print_version
    desc "--version, -v", "Prints package version"
    def __print_version
      puts BooticCli::VERSION
    end

    desc 'setup', 'Setup OAuth2 application credentials'
    def setup
      say "Please create a Bootic app and get its credentials at auth.bootic.net/dev/apps", :yellow

      if current_env != DEFAULT_ENV
        auth_host = ask("Enter auth endpoint host (#{BooticClient::AUTH_HOST}):").chomp
        api_root  = ask("Enter API root (#{BooticClient::API_ROOT}):").chomp
        auth_host = nil if auth_host == ""
        api_root  = nil if api_root == ""
      end

      client_id     = ask("Enter your application's client_id:")
      client_secret = ask("Enter your application's client_secret:")

      session.logout! # ensure existing access tokens are removed
      session.setup(client_id, client_secret, auth_host: auth_host, api_root: api_root)

      if current_env == DEFAULT_ENV
        say "Credentials stored (client_id #{client_id})."
      else
        say "Credentials stored for #{current_env} env (client_id #{client_id})."
      end
    end

    desc 'login', 'Login to your Bootic account'
    def login(scope = 'admin')
      check_client_keys!

      username  = ask("Enter your Bootic email")
      pwd       = ask("Enter your Bootic password:", echo: false)
      say "Loging in as #{username}. Getting access token..."

      begin
        session.login(username, pwd, scope)
        say "Logged in as #{username} (#{scope})"
        say "try: btc help"
      rescue StandardError => e
        say e.message
      end
    end

    desc 'logout', 'Log out (delete access token)'
    def logout
      session.logout!
      say_status 'Logged out', 'You are now logged out', :red
    end

    desc "erase", "Clear all credentials from this computer"
    def erase
      session.erase!
      say "Ok mister. All credentials have been erased."
    end

    desc 'info', 'Test API connectivity'
    def info
      logged_in_action do
        print_table([
          ['username', root.user_name],
          ['email', root.email],
          ['scopes', root.scopes],
          ['shop', "#{shop.url} (#{shop.subdomain})"],
          ['custom commands dir', CUSTOM_COMMANDS_DIR]
        ])

        say_status 'OK', 'API connection is working', :green
      end
    end

    desc 'runner', 'Run an arbitrary ruby script with a client session'
    def runner(filename)
      require 'bootic_cli/file_runner'

      logged_in_action do
        FileRunner.run(root, filename)
      end
    end

    desc 'console', 'Log into interactive console'
    def console
      logged_in_action do
        require 'irb'
        require 'irb/completion'
        require 'irb/ext/multi-irb'
        require 'bootic_cli/console'

        IRB.setup nil
        IRB.conf[:MAIN_CONTEXT] = IRB::Irb.new.context

        context = Console.new(session)
        prompt = "/#{shop.subdomain} (#{root.user_name}|#{root.scopes}) $ "

        IRB.conf[:PROMPT][:CUSTOM] = {
          :PROMPT_I => prompt,
          :PROMPT_S => "%l>> ",
          :PROMPT_C => prompt,
          :PROMPT_N => prompt,
          :RETURN => "=> %s\n"
        }

        IRB.conf[:PROMPT_MODE] = :CUSTOM
        IRB.conf[:AUTO_INDENT] = false

        IRB.irb nil, context
      end
    end

    def self.sub(klass, descr)
      command_name = underscore(klass.name)
      register klass, command_name, "#{command_name} SUBCOMMAND ...ARGS", descr
    end

    private

    def self.underscore(str)
      str.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase.split("/").last
    end

    def self.load_file(f)
      begin
        require f
      rescue LoadError => e
        puts "#{e.class} loading #{f}: #{e.message}"
      end
    end

    require "bootic_cli/command"

    Dir[File.join(File.dirname(__FILE__), 'commands', '*.rb')].each do |f|
      load_file f
    end

    if File.directory?(CUSTOM_COMMANDS_DIR)
      Dir[File.join(CUSTOM_COMMANDS_DIR, '*.rb')].each do |f|
        load_file f
      end
    end
  end
end

