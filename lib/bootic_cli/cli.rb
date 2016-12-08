require 'thor'
require 'bootic_cli/connectivity'
require 'bootic_cli/formatters'

module BooticCli
  class CLI < Thor
    include Thor::Actions
    include BooticCli::Connectivity

    CUSTOM_COMMANDS_DIR = ENV.fetch("BTC_CUSTOM_COMMANDS_PATH") { File.join(ENV["HOME"], "btc") }

    desc 'setup', 'Setup OAuth2 application credentials'
    def setup
      client_id     = ask("Enter your application's client_id:")
      client_secret = ask("Enter your application's client_secret:")

      session.setup(client_id, client_secret)

      say "Credentials stored. client_id: #{client_id}"
    end

    desc 'login', 'Login to your Bootic account'
    def login(scope = 'admin')
      if !session.setup?
        say "App not configured. Running setup first. You only need to do this once."
        say "Please create an OAuth2 app and get its credentials at https://auth.bootic.net/dev/apps"
        invoke :setup, []
      end

      username  = ask("Enter your Bootic user name:")
      pwd       = ask("Enter your Bootic password:", echo: false)

      say "Loging in as #{username}. Getting access token..."

      begin
        session.login username, pwd, scope
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

    desc "erase", "clear all credentials from this computer"
    def erase
      session.erase!
      say "all credentials erased from this computer"
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
        IRB.setup nil
        IRB.conf[:MAIN_CONTEXT] = IRB::Irb.new.context
        require 'irb/ext/multi-irb'
        require 'bootic_cli/console'
        context = Console.new(root)
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
      desc "#{command_name} SUBCOMMAND ...ARGS", descr
      subcommand command_name, klass
    end

    private

    def self.underscore(str)
      str.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    Dir[File.join(File.dirname(__FILE__), 'cli', '*.rb')].each do |f|
      require f
    end

    if File.directory?(CUSTOM_COMMANDS_DIR)
      require "bootic_cli/command"
      Dir[File.join(CUSTOM_COMMANDS_DIR, '*.rb')].each do |f|
        require f
      end
    end
  end
end

