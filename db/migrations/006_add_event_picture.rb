require 'sequel'


Sequel.migration do
  change do 
    alter_table(:events) do 
      add_column :picture_url, String
    end
  end
end

