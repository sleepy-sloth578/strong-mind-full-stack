class CreateRawEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :raw_events do |t|
      t.string   :github_event_id, null: false
      t.string   :event_type,      null: false
      t.jsonb    :payload,          null: false, default: {}
      t.string   :status,          null: false, default: "pending"
      t.text     :error
      t.datetime :fetched_at,      null: false

      t.timestamps
    end

    add_index :raw_events, :github_event_id, unique: true
  end
end
