class AddImages < ActiveRecord::Migration
  def self.up
    create_table :images do |t|
      t.column :title, :string, :null => false
      t.column :description, :text
      t.column :filename, :string, :null => false
      t.column :content_type, :string, :null => false
      t.column :size, :integer, :null => false
      # foreing_key_migrations auto constraint building
      # parent_id in this case, is self-referential
      t.column :parent_id, :integer, :references => :images
      t.column :thumbnail, :string
      t.column :width, :integer
      t.column :height, :integer
      t.column :created_at, :datetime, :null => false
      t.column :updated_at, :datetime, :null => false
    end
  end

  def self.down
    drop_table :images
  end
end
