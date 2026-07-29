require 'thor'
require 'bootic_cli/version'
require 'bootic_cli/connectivity'
require 'bootic_cli/formatters'

module BooticCli

  class CLI < Thor
    include Thor::Actions
    include BooticCli::Connectivity

    CUSTOM_COMMANDS_DIR = ENV.fetch('BTC_CUSTOM_COMMANDS_PATH') { File.join(ENV['HOME'], 'bootic') }

    # override Thor's help method to print banner and check for keys
    def help
      say "Bootic CLI v#{BooticCli::VERSION}\n\n", :bold
      super
      check_client_keys
    end

    map %w[--version -v] => :__print_version
    desc "--version, -v", "Prints package version"
    def __print_version
      puts "#{BooticCli::VERSION} (Ruby #{RUBY_VERSION})"
    end

    desc 'login', 'Login to your Bootic account'
    def login
      require 'launchy'
      require 'bootic_cli/local_server'

      if session.logged_in?
        input = ask "You're already logged in. Re-authenticate? [n]", :magenta
        if input.strip.downcase != 'y'
          say "Already logged in! Try `bootic help`."
          exit(1)
        end
      end

      state = verifier = callback_port = nil
      params = nil

      begin
        params = BooticCli::LocalServer.wait_for_callback do |port|
          callback_port = port
          url, state, verifier = session.authorization_request(port: port)
          say "\nOpening your browser to complete authentication...", :cyan
          say "If it doesn't open automatically, visit:\n#{url}\n", :magenta
          Launchy.open(url)
        end
      rescue BooticCli::LocalServer::NoPortAvailable => e
        say e.message, :red
        exit 1
      rescue BooticCli::LocalServer::TimedOut
        say "Authentication timed out (no response after 2 minutes). Please try again.", :red
        exit 1
      end

      if params['state'] != state
        say "Security error: state mismatch. Please try again.", :red
        exit 1
      end

      if params['error']
        say "Authentication failed: #{params['error_description'] || params['error']}", :red
        exit 1
      end

      begin
        session.login_with_browser(params['code'], code_verifier: verifier, port: callback_port)
        say "\nYou're now logged in!", :green
        say "For a list of available commands, run `bootic help`."
      rescue StandardError => e
        say "Could not exchange token: #{e.message}", :red
        exit 1
      end
    end

    desc 'setup', 'Configure a custom OAuth app (advanced)'
    def setup
      say "Note: `bootic setup` is only needed if you want to use your own OAuth app.", :cyan
      say "For normal use, just run `bootic login`.\n"

      if current_env != DEFAULT_ENV
        auth_host = ask("Auth endpoint host (#{BooticClient.configuration.auth_host}):", :bold).chomp
        api_root  = ask("API root (#{BooticClient.configuration.api_root}):", :bold).chomp
        auth_host = nil if auth_host.empty?
        api_root  = nil if api_root.empty?
      end

      client_id     = ask("Client ID:", :bold)
      client_secret = ask("Client secret:", :bold)

      session.setup(client_id, client_secret, auth_host: auth_host, api_root: api_root)
      say "Custom app credentials stored.", :magenta
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

    desc 'erase', 'Clear all credentials from this computer'
    def erase
      if session.setup?
        session.erase!
        say "Ok mister. All credentials have been erased.", :magenta
      else
        say "Couldn't find any stored credentials.", :red
      end
    end

    desc 'check', 'Test API connectivity'
    def check
      logged_in_action do
        say "Yup, API connection is working!\n\n", :green

        print_table([
          [bold('Email'), root.email],
          [bold('Shop'), "#{shop.url} (#{shop.subdomain})"],
          [bold('Scopes'), root.scopes]
        ])
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
        irb = IRB::Irb.new(IRB::WorkSpace.new(context))

        if irb.respond_to?(:run)
          irb.run
        else
          IRB.conf[:MAIN_CONTEXT] = irb.context

          trap('SIGINT') do
            irb.signal_handle
          end

          begin
            catch(:IRB_EXIT) do
              irb.eval_input
            end
          ensure
            IRB.irb_at_exit
          end
        end
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

    require 'bootic_cli/command'

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

