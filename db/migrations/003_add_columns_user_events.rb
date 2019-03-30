require 'sequel'


Sequel.migration do
  change do 
    alter_table(:users) do 
      add_column :name, String
      add_column :picture, String
      add_column :email, String
    end
  end
end

