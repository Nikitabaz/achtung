
require 'sequel'


Sequel.migration do
  change do 
    alter_table(:events) do 
      add_column :deleted, TrueClass
    end
    alter_table(:comments) do 
      add_column :deleted, TrueClass
    end
  end
end

