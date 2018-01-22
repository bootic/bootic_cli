require 'thor'
require 'bootic_cli/version'
require 'bootic_cli/connectivity'
require 'bootic_cli/formatters'

module BooticCli

  DEFAULT_ENV = 'production'.freeze

  class CLI < Thor
    include Thor::Actions
    include BooticCli::Connectivity

    CUSTOM_COMMANDS_DIR = ENV.fetch("BTC_CUSTOM_COMMANDS_PATH") { File.join(ENV["HOME"], "btc") }

    # override Thor's help method to print banner and check for keys
    def help
      say "Bootic CLI v#{BooticCli::VERSION}\n\n", :bold
      super
      check_client_keys!
    end

    map %w[--version -v] => :__print_version
    desc "--version, -v", "Prints package version"
    def __print_version
      puts BooticCli::VERSION
    end

    desc 'setup', 'Setup Bootic application credentials'
    def setup
      apps_host   = "auth.bootic.net"
      dev_app_url = "#{apps_host}/dev/cli"

      if session.setup?
        input = ask "Looks like you're already set up. Do you want to re-enter your app's credentials? [n]", :magenta
        if input != 'y'
          say 'Thought so. Bye!'
          exit(1)
        end
      else
        say "This CLI uses the #{bold('Bootic API')} in order to interact with your shop's data."
        say "This means you need to create a Bootic app at #{bold(dev_app_url)} to access the API and use the CLI.\n"
      end

      input = ask "Have you created a Bootic app yet? [n]"
      if input == 'y'
        say "Great. Remember you can get your app's credentials at #{bold(dev_app_url)}."
      else
        say "Please visit https://#{bold(dev_app_url)} and hit the 'Create' button."
        sleep 2
        # Launchy.open(apps_url)
        say ""
      end

      if current_env != DEFAULT_ENV
        auth_host = ask("Enter auth endpoint host (#{BooticClient::AUTH_HOST}):", :bold).chomp
        api_root  = ask("Enter API root (#{BooticClient::API_ROOT}):", :bold).chomp
        auth_host = nil if auth_host == ""
        api_root  = nil if api_root == ""
      end

      client_id     = ask("Enter your application's client_id:", :bold)
      client_secret = ask("Enter your application's client_secret:", :bold)

      session.setup(client_id, client_secret, auth_host: auth_host, api_root: api_root)

      if current_env == DEFAULT_ENV
        say "Credentials stored!", :magenta
      else
        say "Credentials stored for #{current_env} env.", :magenta
      end

      return if ENV['nologin']

      say ""
      sleep 3
      login
    end

    desc 'login', 'Login to your Bootic account'
    def login(scope = 'admin')
      if !session.setup?
        say "App not configured for #{options[:environment]} environment. Running setup first. You only need to do this once.", :red
        invoke :setup, []
      end

      if session.logged_in?
        input = ask "Looks like you're already logged in. Do you want to redo this step? [n]", :magenta
        if input != 'y'
          say 'Thought so. Bye!'
          exit(1)
        end
      end

      username  = ask("Enter your Bootic email:", :bold)
      pwd       = ask("Enter your Bootic password:", :bold, echo: false)

      if username.strip == '' or pwd.strip == ''
        say "\nPlease make sure to enter valid data.", :red
        exit 1
      end

      say "\n\nAlrighty! Getting access token for #{username}...\n"

      begin
        session.login(username, pwd, scope)
        say "Great success! You're now logged in as #{username} (#{scope})", :green
        say "For a list of available commands, run `bootic help`."
      rescue StandardError => e
        say e.message, :red
        if e.message['No application with client ID']
          sleep 2
          say "\nTry running `bootic setup` again. Or perhaps you missed the ENV variable?", :magenta
        end
      end
    end

    desc 'logout', 'Log out (delete access token)'
    def logout
      if session.logged_in?
        session.logout!
        say 'Done. You are now logged out.', :magenta
      else
        say "You're not logged in. Did you mean `bootic login` perhaps?", :red
      end
    end

    desc "erase", "clear all credentials from this computer"
    def erase
      if session.setup?
        session.erase!
        say "Ok mister. All credentials have been erased.", :magenta
      else
        say "Couldn't find any stored credentials.", :red
      end
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

        say 'Yup, API connection is working!', :green
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
        IRB.setup nil
        IRB.conf[:MAIN_CONTEXT] = IRB::Irb.new.context
        require 'irb/ext/multi-irb'
        require 'bootic_cli/console'
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

    def bold(str)
      set_color(str, :bold)
    end

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

