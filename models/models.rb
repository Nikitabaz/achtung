require 'sequel'

class Tag < Sequel::Model
  many_to_many :users, :join_table => :tag_user, :left_key => :tag_id, :right_key => :user_id
  many_to_many :tags, :join_table => :event_tag, :left_key => :tag_id, :right_key => :event_id
end

class User < Sequel::Model(:users)
  many_to_many :tags, :join_table => :tag_user, :left_key => :user_id, :right_key => :tag_id
  many_to_many :events, :join_table => :event_user, :left_key => :user_id, :right_key => :event_id
end

class Event < Sequel::Model(:events)
  many_to_many :users, :join_table => :event_user, :left_key => :event_id, :right_key => :user_id
  many_to_many :tags, :join_table => :event_tag, :left_key => :event_id, :right_key => :tag_id

  one_to_many :comments
end

class Comment < Sequel::Model(:comments)
  many_to_many :comments, :join_table => :comment_dep, :left_key => :child_id, :right_key => :parent_id
end
