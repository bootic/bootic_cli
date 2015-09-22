require 'thor'
require 'btc/connectivity'

module Btc
  class CLI < Thor
    include Thor::Actions
    include Btc::Connectivity

    package_name "Auth" 

    desc 'setup', 'Setup OAuth2 application credentials'
    def setup
      client_id     = ask("Enter your applications client_id:")
      client_secret = ask("Enter your application's client_secret:")

      store.transaction do
        store['client_id'] = client_id
        store['client_secret'] = client_secret
      end

      say "Credentials stored. client_id: #{client_id}"
    end

    desc 'login', 'Login to your Bootic account'
    def login
      if !setup?
        say "App not configured. Running setup first."
        invoke :setup
      end

      username  = ask("Enter your Bootic user name:")
      pwd       = ask("Enter your Bootic password:", echo: false)

      say "Loging in as #{username}. Getting access token..."

      begin
        token = oauth_client.password.get_token(username, pwd, 'scope' => 'admin')

        store.transaction do
          store['access_token'] = token.token
        end

        say "Logged in"
      rescue StandardError => e
        say e.message
      end
    end

    desc 'test', 'Test API connectivity'
    def test
      if !setup?
        say_status "ERROR", "No app credentials. Run btc setup", :red
        return
      end

      if !has_token?
        say_status "ERROR", "No access token. Run btc login", :red
        return
      end

      begin
        print_table([
          ['username', root.user_name],
          ['email', root.email],
          ['scopes', root.scopes],
          ['shop', shop.url]
        ])

        say_status 'OK', 'API connection is working', :green
      rescue StandardError => e
        say_status "ERROR", e.message, :red
      end

    end

    desc 'console', 'Log into interactive console'
    def console
      if !ready?
        say_status 'ERROR', 'Not logged in. Run btc login first', :red
        return
      end

      require 'irb'
      require 'irb/completion'
      IRB.setup nil
      IRB.conf[:MAIN_CONTEXT] = IRB::Irb.new.context
      require 'irb/ext/multi-irb'
      require 'btc/console'
      context = Console.new
      prompt = "/btc (#{root.user_name}|#{root.scopes}) $ "

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
end
