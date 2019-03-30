require 'google/apis/calendar_v3'
require 'google/api_client/client_secrets'
require 'json'
require 'sinatra'
require 'logger'
require 'pry'

set :port, 8080

enable :sessions
set :session_secret, ENV['SESSION_SECRET']

def logger; settings.logger end

def calendar; settings.calendar; end

def user_credentials
  # Build a per-request oauth credential based on token stored in session
  # which allows us to use a shared API client.
  @authorization ||= (
  auth = settings.authorization.dup
  auth.redirect_uri = to('/oauth2callback')
  auth.update_token!(session)
  auth
  )
end

configure do
  log_file = File.open('calendar.log', 'a+')
  log_file.sync = true
  logger = Logger.new(log_file)
  logger.level = Logger::DEBUG

  Google::Apis::ClientOptions.default.application_name = 'Ruby Calendar sample'
  Google::Apis::ClientOptions.default.application_version = '1.0.0'
  calendar_api = Google::Apis::CalendarV3::CalendarService.new

  client_secrets = Google::APIClient::ClientSecrets.load
  authorization = client_secrets.to_authorization
  authorization.scope = 'https://www.googleapis.com/auth/calendar'

  set :authorization, authorization
  set :logger, logger
  set :calendar, calendar_api
end


before do
  # Ensure user has authorized the app
  unless user_credentials.access_token || request.path_info =~ /^\/oauth2/
    redirect to('/oauth2authorize')
  end
end

after do
  # Serialize the access/refresh token to the session and credential store.
  session[:access_token] = user_credentials.access_token
  session[:refresh_token] = user_credentials.refresh_token
  session[:expires_in] = user_credentials.expires_in
  session[:issued_at] = user_credentials.issued_at
end

get '/oauth2authorize' do
  # Request authorization
  redirect user_credentials.authorization_uri.to_s, 303
end

get '/oauth2callback' do
  # Exchange token
  user_credentials.code = params[:code] if params[:code]
  user_credentials.fetch_access_token!
  redirect to('/')
end

get '/' do
  # Fetch list of events on the user's default calandar
  events = calendar.list_events('primary', options: { authorization: user_credentials })
  [200, {'Content-Type' => 'application/json'}, events.to_h.to_json]
end




get '/login' do
  File.read(File.join('public', 'index_login.html'))
end

get '/index' do
  File.read(File.join('public', 'index.html'))
end

# get '/oauth2callback' do
#   client_secrets = Google::APIClient::ClientSecrets.load
#   auth_client = client_secrets.to_authorization
#   auth_client.update!(
#       :scope => 'https://www.googleapis.com/auth/drive.metadata.readonly',
#       :redirect_uri => url('/oauth2callback'))
#   if request['code'] == nil
#     auth_uri = auth_client.authorization_uri.to_s
#     redirect to(auth_uri)
#   else
#     auth_client.code = request['code']
#     auth_client.fetch_access_token!
#     auth_client.client_secret = nil
#     session[:credentials] = auth_client.to_json
#     redirect to('/')
#   end
# end