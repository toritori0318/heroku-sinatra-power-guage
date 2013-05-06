# -*- encoding: utf-8 -*-
require "bundler"
require 'pp'

Bundler.setup(:default)
Bundler.require

use Rack::Session::Pool, :expire_after => 86400 * 30 # 1 day

set :session_secret, "Some random and long sequence"

TWITTER_CONSUMER_KEY    = ""
TWITTER_CONSUMER_SECRET = ""

use OmniAuth::Builder do
  provider :twitter, TWITTER_CONSUMER_KEY, TWITTER_CONSUMER_SECRET
end

def twitter_client(auth)
  return Twitter::Client.new(
    :consumer_key       => TWITTER_CONSUMER_KEY,
    :consumer_secret    => TWITTER_CONSUMER_SECRET,
    :oauth_token        => auth['token'],
    :oauth_token_secret => auth['secret'],
  )
end

get "/" do
  auth_keys = session[:auth]
  if auth_keys then
    @twitter_client = twitter_client(session[:auth])
    @screen_name = @twitter_client.user.screen_name
  end

  erb :index
end

get "/auth/twitter/callback" do
  auth = request.env["omniauth.auth"]

  if auth then
    auth_keys = { "token"=>auth.credentials.token, "secret"=>auth.credentials.secret }
    session[:auth] = auth_keys
    redirect "/"
  else
    redirect "/fail"
  end
end

get "/auth/failure" do
  redirect "/fail"
end

post "/power_guage" do
  @twitter_client = twitter_client(session[:auth])
  @screen_name = @twitter_client.user.screen_name

  power = params[:power]
  if power == "random"
    power = rand(10) + 1
  else
    power = power.to_i
    if power >= 1 && power <= 10
      power
    else
      $stderr << "power validation error\n"
      redirect "/fail"
    end
  end

  @guage = sprintf("[%s%s]", ('▮' * power), ('▯' * (10-power)) )

  name = @twitter_client.user.name
  if name =~ /\[[▮▯]+\]$/ then
    name = name.gsub(/\[.*\]$/m, @guage)
  else
    name = name + @guage
  end

  begin
    @twitter_client.update_profile(:name => name)
  rescue Exception => error
    $stderr << "#{error.class} => #{error.message}\n"
    $stderr << error.backtrace.join("\n") << "\n"
    redirect "/fail"
  end

  erb :power_guage
end

post "/clean_guage" do
  @twitter_client = twitter_client(session[:auth])
  @screen_name = @twitter_client.user.screen_name

  @name = @twitter_client.user.name
  if @name =~ /\[[▮▯]+\]$/ then
    @name = @name.gsub(/(\[.*\])$/m, '')
  else
    erb :clean_guage
  end

  begin
    @twitter_client.update_profile(:name => @name)
  rescue Exception => error
    $stderr << "#{error.class} => #{error.message}\n"
    $stderr << error.backtrace.join("\n") << "\n"
    redirect "/fail"
  end

  erb :clean_guage
end

get "/fail" do
  erb :fail
end
