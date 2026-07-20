class CreateActors < ActiveRecord::Migration[8.1]
  def change
    create_table :actors do |t|
      t.bigint   :github_id, null: false
      t.string   :login
      t.string   :name
      t.string   :avatar_url
      t.string   :actor_type
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :actors, :github_id, unique: true
  end
end
