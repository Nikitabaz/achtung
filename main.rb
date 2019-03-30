require 'google/apis/calendar_v3'
require 'google/apis/oauth2_v2'
require 'google/api_client/client_secrets'
require 'json'
require 'sinatra'
require 'logger'
require 'pry'
require 'colorize'

set :port, 8080
set :bind, '0.0.0.0'

set :root, File.dirname(__FILE__)


def logger; settings.logger end

def calendar; settings.calendar; end

def oauth2; settings.oauth2; end

def auth; settings.authorization; end

# def user_credentials
#   # Build a per-request oauth credential based on token stored in session
#   # which allows us to use a shared API client.
#   authorization = (
#     auth = settings.authorization.dup
#     auth.redirect_uri = to('/oauth2callback')
#     auth.update_token!(session)
#     auth
#   )
#   authorization
# end

configure do
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG


  use Rack::Session::Cookie, :key => 'rack.session',
      :domain => 'localhost',
      :path => '/',
      :expire_after => 60*60*1, # In seconds
      :secret => ENV['SESSION_SECRET']

  Google::Apis::ClientOptions.default.application_name = 'Ruby Calendar sample'
  Google::Apis::ClientOptions.default.application_version = '1.0.0'
  calendar_api  = Google::Apis::CalendarV3::CalendarService.new
  oauth2_api        = Google::Apis::Oauth2V2::Oauth2Service.new

  client_secrets = Google::APIClient::ClientSecrets.load
  authorization = client_secrets.to_authorization
  authorization.scope = [
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/plus.me',
      'https://www.googleapis.com/auth/userinfo.profile'
  ]

  set :authorization, authorization
  set :logger,        logger
  set :calendar,      calendar_api
  set :oauth2,        oauth2_api
end

before do
  # Ensure user has authorized the app

  puts "\n\nBEFORE | #{request.url.to_s.bold.yellow}"
  puts "SESSION | #{session.pretty_inspect.to_s.green}"

  if request.path_info == '://localhost::0'
    redirect to('/index')
  end

  pass if request.path_info =~ /^\/signout/
  pass if request.path_info =~ /^\/oauth2/

  # binding.pry if session[:access_token].nil?

  puts "COOKIES: #{request.cookies}"

  puts "MINE SESSION: #{session[:session_id].to_s.magenta.bold}"

  if !authorized?
    session[:initial_url] = request.url
    authorize!
  else
    session[:initial_url] = nil
  end
end

def authorize!
  redirect to('/oauth2authorize')
end

def authorized?
  session[:access_token]
end

after do
  puts "\n\nAFTER | #{request.url.to_s.bold.yellow}"
  puts "SESSION | #{session.pretty_inspect.to_s.green}"

  # Serialize the access/refresh token to the session and credential store.
end

get '/oauth2authorize' do
  # Request authorization
  auth.redirect_uri = to('/oauth2callback')
  redirect auth.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  current_auth      = auth.dup
  current_auth.code = params[:code] if params[:code]
  current_auth.fetch_access_token!

  session[:access_token]  = current_auth.access_token
  session[:refresh_token] = current_auth.refresh_token
  session[:expires_in]    = current_auth.expires_in
  session[:issued_at]     = current_auth.issued_at
  session[:user_info]     = current_auth ? oauth2.get_userinfo(options: { authorization: current_auth } ).to_h : nil

  redirect to(session[:initial_url])
end

get '/' do
  redirect to('/index')
end

get '/calendar/events' do
  # binding.pry
  time_min = params['time_min'] ? DateTime.parse(params['time_min']) : DateTime.now.rfc3339
  binding.pry
  events = calendar.list_events('primary', time_min: time_min, options: { authorization: auth.dup.update_token!(session) })
  events = events.items.select{|e| e.status == 'confirmed' }.map do |e|
    format_event(e)
  end
  [200, {'Content-Type' => 'application/json'}, events.to_json]
end

delete '/calendar/events/:event_id' do |event_id|
  calendar.delete_event('primary', event_id, options: { authorization: auth.dup.update_token!(session) })
end

get '/calendar/events/:event_id' do |event_id|
  event = calendar.get_event('primary', event_id , options: { authorization: auth.dup.update_token!(session) })
  [200, {'Content-Type' => 'application/json'}, event.to_h.to_json]
end

post '/calendar/events/new' do
  data = JSON.parse(request.body.read)
  binding.pry
  event = create_event_from_post_body(data)
  event = calendar.insert_event('primary', event, options: { authorization: auth.dup.update_token!(session) })
  [200, {'Content-Type' => 'application/json'}, event.to_json]
end

post '/calendar/events/:event_id' do |event_id|
  data = JSON.parse(request.body.read)
  binding.pry
  event = create_event_from_post_body(data)
  event = calendar.update_event('primary', event, event_id, options: { authorization: auth.dup.update_token!(session) })
  [200, {'Content-Type' => 'application/json'}, event.to_json]
end


def format_event(e)
  duration = e.end.date_time - e.start.date_time if !e.end.date_time.nil? && !e.start.date_time.nil?
  {
      id:           e.id,
      name:         e.summary,
      description:  e.description,
      starts_at:    e.start.date_time,
      ends_at:      e.end.date_time,
      location:     e.location,
      attendees:    e.attendees.select{ |a| !a.resource },
      reccurence:   e.recurrence,
      duration:     duration
  }
end

def create_event_from_post_body(d)
  d
end

get '/login' do
  File.read(File.join('public', 'index_login.html'))
end

get '/index' do
  # "TEST"
  File.read(File.join('public', 'index.html'))
end

get '/event' do
  File.read(File.join('public', 'event.html'))
end

get '/profile' do
  File.read(File.join('public', 'profile.html'))
end
