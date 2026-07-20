class CreatePushEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :push_events do |t|
      t.bigint :push_id,         null: false
      t.string :ref
      t.string :head
      t.string :before
      t.bigint :repo_github_id,  null: false
      t.bigint :actor_github_id, null: false

      t.references :raw_event,  null: false, foreign_key: true, index: false
      t.references :repository, null: false, foreign_key: true, index: false
      t.references :actor,      null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :push_events, :push_id, unique: true
  end
end
