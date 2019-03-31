require 'sinatra/base'
require 'sinatra'
require File.expand_path('main', File.dirname(__FILE__))

map('/') { run ApplicationController }
map('/event/') { run EventListController }
map('/comment/') { run CommentsController }
