require 'sequel'


Sequel.migration do
  change do 
    create_table(:tags) do 
      primary_key :id
      String :name, :null => false
    end

    create_table(:users) do 
      primary_key :id
    end

    create_table(:tag_user) do 
      foreign_key :tag_id, :tags
      foreign_key :user_id, :users
    end

    create_table(:events) do 
      primary_key :id
      foreign_key :creator_id, :users
    end

    create_table(:event_user) do 
      foreign_key :event_id, :events
      foreign_key :user_id, :users
    end

    create_table(:comments) do 
      primary_key :id
      foreign_key :event_id, :events
      foreign_key :user_id, :users
    end

    create_table(:comment_dep) do 
      foreign_key :parent_id, :comments
      foreign_key :child_id, :comments
    end
  end
end

