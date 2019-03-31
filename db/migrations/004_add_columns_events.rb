require 'sequel'


Sequel.migration do
  change do 
    alter_table(:events) do
      add_column :google_id, String
    end
  end
end

