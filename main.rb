require 'sinatra'

set :port, 8080

get '/login' do
  File.read(File.join('public', 'index_login.html'))
end

get '/index' do
  File.read(File.join('public', 'index.html'))
end