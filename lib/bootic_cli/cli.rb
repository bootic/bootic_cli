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

    desc 'setup', 'Setup Bootic application credentials'
    def setup
      apps_host   = "auth.bootic.net"
      dev_app_url = "#{apps_host}/dev/cli"

      if session.setup?
        input = ask "Looks like you're already set up. Do you want to re-enter your app's credentials? [n]", :magenta
        if input != 'y'
          say 'Thought so. You can run `bootic help` for a list of supported commands.'
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
        auth_host = ask("Enter auth endpoint host (#{BooticClient.configuration.auth_host}):", :bold).chomp
        api_root  = ask("Enter API root (#{BooticClient.configuration.api_root}):", :bold).chomp
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
          say "That's what I thought! Try running `bootic help`."
          exit(1)
        end
      end

      email = ask("Enter your Bootic email:", :bold)
      pass  = ask("Enter your Bootic password:", :bold, echo: false)

      if email.strip == '' or email['@'].nil? or pass.strip == ''
        say "\nPlease make sure to enter valid data.", :red
        exit 1
      end

      say "\n\nAlrighty! Getting access token for #{email}...\n"

      begin
        session.login(email, pass, scope)
        say "Great success! You're now logged in as #{email} (#{scope})", :green
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

