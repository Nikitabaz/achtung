require_relative "../models/models"
require 'pry'
require 'json'

class EventListController < ApplicationController
  get "/list" do
    events = Event.all.map { |event| event.to_hash }
    return [200, events.to_json]
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
            :children => comment.children.map { |child| child.to_hash }
          })
        }
      })
      return [200, response.to_json]
    else
      return [404]
    end
  end

  post "/create" do
    binding.pry
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
    redirect "/event/#{event[:id]}"
  end
end

class CommentsController < ApplicationController
  post "/create" do
    binding.pry
    event = Event.where(:id => params[:event_id]).all.first
    comment = Comment.create({
      text: params[:text]
    })
    JSON(params[:parent_ids] || "[]").each do |parent_id|
      parent = Comment.where(:id => parent_id).all.first
      comment.add_parent parent
    end
    event.add_comment comment
    redirect "/event/#{params[:event_id]}"
  end
end
