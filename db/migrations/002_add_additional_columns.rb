require 'sequel'


Sequel.migration do
  change do 

    create_table(:event_tag) do 
      foreign_key :tag_id, :tags
      foreign_key :event_id, :events
    end

    alter_table(:events) do 
      add_column :name, String
      add_column :description, String
      add_column :start_time, DateTime
      add_column :end_time, DateTime
      add_column :location, String
      add_column :cron, String
      add_column :recurent, TrueClass
    end

    alter_table(:comments) do
      add_column :text, String
    end

  end
end

