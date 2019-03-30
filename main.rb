require 'google/apis/calendar_v3'
require 'google/api_client/client_secrets'
require 'json'
require 'sinatra'
require 'pry'

set :port, 8080

get '/login' do
  File.read(File.join('public', 'index_login.html'))
end

get '/index' do
  File.read(File.join('public', 'index.html'))
end

enable :sessions
set :session_secret, ENV['SESSION_SECRET']

get '/' do
  client_secrets = Google::APIClient::ClientSecrets.load
  unless session.has_key?(:credentials)
    redirect to('/login')
    redirect to('/oauth2callback')
  end
  client_opts = JSON.parse(session[:credentials])
  auth_client = Signet::OAuth2::Client.new(client_opts)
  redirect to('/index')
  # "WE MADE IT"
  # "<pre>#{JSON.pretty_generate(files.to_h)}</pre>"
end

get '/oauth2callback' do
  client_secrets = Google::APIClient::ClientSecrets.load
  auth_client = client_secrets.to_authorization
  auth_client.update!(
      :scope => 'https://www.googleapis.com/auth/drive.metadata.readonly',
      :redirect_uri => url('/oauth2callback'))
  if request['code'] == nil
    auth_uri = auth_client.authorization_uri.to_s
    redirect to(auth_uri)
  else
    auth_client.code = request['code']
    auth_client.fetch_access_token!
    auth_client.client_secret = nil
    session[:credentials] = auth_client.to_json
    redirect to('/')
  end
end