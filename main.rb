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

require 'active_support/values/time_zone'

class ApplicationController < Sinatra::Base

  set :port, 8080
  set :bind, '0.0.0.0'

  set :root, File.dirname(__FILE__)

  def logger;
    settings.logger
  end

  def calendar;
    settings.calendar;
  end

  def oauth2;
    settings.oauth2;
  end

  def auth;
    settings.authorization;
  end

  configure do
    log_file = File.open('calendar.log', 'a+')
    log_file.sync = true
    logger = Logger.new(log_file)
    logger.level = Logger::DEBUG


    use Rack::Session::Cookie, :key => 'rack.session',
        :domain => 'localhost',
        :path => '/',
        :expire_after => 60 * 60 * 1, # In seconds
        :secret => ENV['SESSION_SECRET']

    Google::Apis::ClientOptions.default.application_name = 'Ruby Calendar sample'
    Google::Apis::ClientOptions.default.application_version = '1.0.0'
    calendar_api = Google::Apis::CalendarV3::CalendarService.new
    oauth2_api = Google::Apis::Oauth2V2::Oauth2Service.new

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

    set :app_name, 'Nicht Arbeiten'

    set :time_zone, ActiveSupport::TimeZone::MAPPING['Minsk']

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
    current_auth = auth.dup
    current_auth.code = params[:code] if params[:code]
    current_auth.fetch_access_token!

    session[:access_token] = current_auth.access_token
    session[:refresh_token] = current_auth.refresh_token
    session[:expires_in] = current_auth.expires_in
    session[:issued_at] = current_auth.issued_at
    session[:user_info] = current_auth ? oauth2.get_userinfo(options: {authorization: current_auth}).to_h : nil

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
    erb :index, :locals => {'meeting_rooms' => EventListController::MEETING_ROOMS}
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

class EventListController < ApplicationController

  MEETING_ROOMS = {
      'Minsk-8-Ireland-Dublin (12)' =>  {
          calendar_id: 'profitero.com_3835373939303534393136@resource.calendar.google.com',
          capacity: 12
      },
      'Minsk-8-UK-London (6)' =>  {
          calendar_id: 'profitero.com_3336373732393733313333@resource.calendar.google.com',
          capacity: 6
      },
      'Minsk-9-Aquarium (7)' =>  {
          calendar_id: 'profitero.com_37363937353439373536@resource.calendar.google.com',
          capacity: 7
      },
      'Minsk-9-Canteen (9)' =>  {
          calendar_id: 'profitero.com_3737313636363735323131@resource.calendar.google.com',
          capacity: 9
      },
      'Minsk-9-Terrarium (Little) (7)' =>  {
          calendar_id: 'profitero.com_3439323930333835373331@resource.calendar.google.com',
          capacity: 7
      },
      'Minsk-20-Crystal (4)' =>  {
          calendar_id: 'profitero.com_3732393236333536353235@resource.calendar.google.com',
          capacity: 4
      },
      'Minsk-20-Gems (4)' =>  {
          calendar_id: 'profitero.com_3635383335353139313231@resource.calendar.google.com',
          capacity: 4
      },
      'Minsk-20-Marble (12)' =>  {
          calendar_id: 'profitero.com_353839323130363934@resource.calendar.google.com',
          capacity: 12
      },
      'Minsk-20-Wood (4)' =>  {
          calendar_id: 'profitero.com_3639383539333932343034@resource.calendar.google.com',
          capacity: 4
      },
      'Minsk-8-Ireland-Cork (2)' =>  {
          calendar_id: 'profitero.com_3733303638393130393934@resource.calendar.google.com',
          capacity: 2
      },
      'Minsk-8-Ireland-Irish Kitchen (4)' =>  {
          calendar_id: 'profitero.com_3638363531303332353436@resource.calendar.google.com',
          capacity: 4
      },
      'Minsk-8-UK-British Kitchen (8)' =>  {
          calendar_id: 'profitero.com_3630303336393735353139@resource.calendar.google.com',
          capacity: 8
      },
      'Minsk-8-USA-Aliaska (2)' =>  {
          calendar_id: 'profitero.com_3735313932393532393834@resource.calendar.google.com',
          capacity: 2
      },
      'Minsk-8-USA-Amerikan Kitchen (10)' =>  {
          calendar_id: 'profitero.com_3134373438323331313237@resource.calendar.google.com',
          capacity: 10
      },
      'Minsk-8-USA-Boston (50)' =>  {
          calendar_id: 'profitero.com_35363534323539313233@resource.calendar.google.com',
          capacity: 59
      }
  }

  def create_event_from_post_body(name: name,
                                  location: location,
                                  description: description,
                                  start_time: start_time,
                                  end_time: end_time,
                                  location_email: location_email)
    Google::Apis::CalendarV3::Event.new( summary: name,
                                         location: location,
                                         description: description,
                                         start: {
                                             date_time: start_time,
                                             time_zone: settings.time_zone
                                         },
                                         end: {
                                             date_time: end_time,
                                             time_zone: settings.time_zone
                                         },
                                         attendees: [
                                             {
                                                 email: get_user.email,
                                                 responseStatus: 'accepted'
                                             },
                                             {
                                                 email: location_email,
                                                 responseStatus: 'needsAction',
                                                 resource: true
                                             }
                                         ],
                                         reminders: {
                                             use_default: false,
                                         }

    )
  end

  def is_location_free?(location, start_time, end_time)
    time_min = nil
    time_max = nil
    time_min = start_time if start_time
    time_max = end_time if end_time

    events = calendar.list_events(location[:calendar_id], time_min: time_min, time_max: time_max, options: {authorization: auth.dup.update_token!(session)})
    events.items.empty?
  end

  get "/list" do
    @error_message = session.delete(:flash_error)

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
    @events = events
    erb :events
  end

  get "/:id" do |id|
    event = Event.where(:id => id).all.first
    if event
      binding.pry
      @event = event
      erb :event
    else
      return [404]
    end
  end

  post "/create" do

    binding.pry

    name        = params[:name]
    location    = params[:location]
    description = params[:description]
    start_time  = DateTime.parse(params[:start_time])
    end_time    = DateTime.parse(params[:end_time])

    location_object = MEETING_ROOMS[location]

    unless location_object && is_location_free?(location_object, start_time.rfc3339, end_time.rfc3339)
      session[:flash_error] = "Location #{location} is busy at selected time window: #{start_time.strftime("%F %T")} - #{end_time.strftime("%F %T")}"
      redirect to("/list")
    end

    google_event = create_event_from_post_body(
        name:           name,
        location:       location,
        description:    description,
        start_time:     start_time.rfc3339,
        end_time:       end_time.rfc3339,
        location_email: location_object[:calendar_id]
    )

    google_event = calendar.insert_event('primary', google_event, options: {authorization: auth.dup.update_token!(session)})

    event = Event.create({
                             name:        params[:name],
                             description: params[:description],
                             start_time:  start_time,
                             end_time:    end_time,
                             location:    params[:location],
                             picture_url: params[:picture_url],
                             google_id:   google_event.id,
                             deleted:     false
                         })

    binding.pry

    tags = params[:tags].empty? ? [] : params[:tags].split(',').map{|s| s.strip}
    tags.each do |tag_str|
      tag = Tag.where(:name => tag_str).all.first || Tag.create(:name => tag_str)
      event.add_tag tag
    end

    event.update(:creator => get_user)
    event.add_user get_user

    event.save

    redirect "/event/#{event[:id]}"
  end

  post "/:id" do |id|
    event = Event.where(:id => id).all.first
    if get_user.id == event.creator.id
      event.update(name: params[:name]) if params[:name]
      event.update(description: params[:description]) if params[:description]
      event.update(start_time: params[:start_time]) if params[:start_time]
      event.update(end_time: params[:end_time]) if params[:end_time]
      event.update(location: params[:location]) if params[:location]
      tags = params[:tags].empty? ? [] : params[:tags].split(',').map{|s| s.strip}
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

  delete "/:id" do |id|
    event = Event.where(id: id).first

    calendar.delete_event('primary', event.google_id, options: {authorization: auth.dup.update_token!(session)})
    event.delete

    redirect to("/list")
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
