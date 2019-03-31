require 'google/apis/calendar_v3'
require 'google/apis/oauth2_v2'
require 'google/api_client/client_secrets'
require 'json'
require 'sinatra'
require 'sinatra/base'
require 'logger'
require 'pry'
require 'pry-byebug'
require 'sequel'
require 'sqlite3'

require 'colorize'


# require_relative "controllers/event_controller.rb"


# Dir.glob('./controllers/*.rb').each { |file| require file }


class ApplicationController < Sinatra::Base

  set :port, 8080
  set :bind, '0.0.0.0'

  set :root, File.dirname(__FILE__)

  def logger; settings.logger end

  def calendar; settings.calendar; end

  def oauth2; settings.oauth2; end

  def auth; settings.authorization; end

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
        'https://www.googleapis.com/auth/userinfo.profile',
        'https://www.googleapis.com/auth/userinfo.email'
    ]

    set :authorization, authorization

    set :logger, logger
    set :calendar, calendar_api
    set :oauth2, oauth2_api

    set :app_name, 'Achtung!'


    set :db, Sequel.connect("sqlite://db/development.sqlite3")
    require_relative "./models/models"
  end

  # use EventListController
  # use CommentsController

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


  get '/login' do
    File.read(File.join('public', 'index_login.html'))
  end

  get '/index' do
    # "TEST"
    erb :index
  end

  def get_user
    user_info = session["user_info"]
    User.where(:email => user_info[:email]).all.first || User.create({
      :name => user_info[:name],
      :email => user_info[:email],
      :picture => user_info[:picture]
    })
  end
end

class CalendarController < ApplicationController
  get '/events' do
    # binding.pry
    time_min = params['time_min'] ? DateTime.parse(params['time_min']) : DateTime.now.rfc3339
    events = calendar.list_events('primary', time_min: time_min, options: { authorization: auth.dup.update_token!(session) })
    events = events.items.select{|e| e.status == 'confirmed' }.map do |e|
      format_event(e)
    end
    [200, {'Content-Type' => 'application/json'}, events.to_json]
  end

  delete '/events/:event_id' do |event_id|
    calendar.delete_event('primary', event_id, options: { authorization: auth.dup.update_token!(session) })
  end

  get '/events/:event_id' do |event_id|
    event = calendar.get_event('primary', event_id , options: { authorization: auth.dup.update_token!(session) })
    [200, {'Content-Type' => 'application/json'}, event.to_h.to_json]
  end

  post '/events/new' do
    data = JSON.parse(request.body.read)
    event = create_event_from_post_body(data)
    event = calendar.insert_event('primary', event, options: { authorization: auth.dup.update_token!(session) })
    [200, {'Content-Type' => 'application/json'}, event.to_json]
  end

  post '/events/:event_id' do |event_id|
    data = JSON.parse(request.body.read)
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
end

class EventListController < ApplicationController
  get "/list" do
    binding.pry
    events = Event.where(:deleted => false)
    query = Event.where(:deleted => false)
    if tags = params['tags']
      query = query.join(:tag_event, event_id: :id).where(:tag_id => tags)
    elsif start_time = params[:start_time]
      query = query.where(:start_time > start_time)
    elsif end_time = params[:end_time]
      query = query.where(:end_time < end_time)
    end
    events = query.all
    if params[:recommend]
      user_tag_ids = get_user.tags.map { |tag| tag.id }
      events = events.all.select do |event|
        event_tag_ids = event.tags.map { |tag| tag.id }
        (user_tag_ids | event_tag_ids).size != (event_tag_ids.size + user_tag_ids.size)
      end
    end
    return [200, events.map { |event| event.to_hash }.to_json]
  end

  get "/:id" do |id|
    event = Event.where(:id => id).all.first
    if event
      tags = event.tags.map { |tag| tag.to_hash }
      response = event.to_hash.merge({
        :tags => tags
      }).merge({
        :comments => event.comments.map { |comment|
          comment.to_hash.merge({
            :children => comment.children.map { |child| child.to_hash },
            :creator => comment.creator.to_hash
          })
        }
      })
      return [200, response.to_json]
    else
      return [404]
    end
  end

  post "/:id" do |id|
    event = Event.where(:id => id).all.first
    if get_user.id == event.creator.id
      event.update(name: params[:name]) if params[:name]
      event.update(description: params[:description]) if params[:description]
      event.update(start_time: params[:start_time]) if params[:start_time]
      event.update(end_time: params[:end_time]) if params[:end_time]
      event.update(location: params[:location]) if params[:location]
      tags = JSON(params[:tags])
      tags.each do |tag_str|
        tag = Tag.where(:name => tag_str).all.first || Tag.create(:name => tag_str)
        event.add_tag tag
      end
    end
    redirect "/event/#{event[:id]}"
  end

  delete "/:id" do |id|
    event = Event.where(:id => id).all.first
    if get_user.id == event.creator.id
      event.update(:deleted => true)
    end
  end

  get "/subscribe/:id" do |id|
    event = Event.where(:id => id).all.first
    unless event.users.find { |sub| sub.id == get_user.id }
      event.add_user(get_user)
      return [200, {success: true}.to_json]
    else
      return [200, {success: false}.to_json]
    end
  end

  post "/create" do
    event = Event.create({
      name: params[:name],
      description: params[:description],
      start_time: params[:start_time],
      end_time: params[:end_time],
      location: params[:location],
    })
    tags = JSON(params[:tags])
    tags.each do |tag_str|
      tag = Tag.where(:name => tag_str).all.first || Tag.create(:name => tag_str)
      event.add_tag tag
    end
    event.update(:creator => get_user)
    event.add_user get_user
    redirect "/event/#{event[:id]}"
  end
end

class CommentsController < ApplicationController
  post "/create" do
    event = Event.where(:id => params[:event_id]).all.first
    comment = Comment.create({
      text: params[:text]
    })
    JSON(params[:parent_ids] || "[]").each do |parent_id|
      parent = Comment.where(:id => parent_id).all.first
      comment.add_parent parent
    end
    event.add_comment comment
    comment.creator = get_user
    redirect "/event/#{params[:event_id]}"
  end
end


get '/template' do
  erb :index, layout: :layout
end
