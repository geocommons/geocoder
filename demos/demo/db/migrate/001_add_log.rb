class AddLog < ActiveRecord::Migration
  def self.up
    create_table :geocoder_logs do |t|
      t.column :geocodes, :integer
      t.column :geocoded_at, :datetime
      t.column  :failed, :integer
    end
  end
  
  
  def self.down
    drop_table :replies
  end
end