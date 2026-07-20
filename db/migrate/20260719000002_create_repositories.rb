class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.bigint   :github_id, null: false
      t.string   :full_name
      t.text     :description
      t.string   :language
      t.integer  :stargazers_count
      t.integer  :forks_count
      t.datetime :fetched_at

      t.timestamps
    end

    add_index :repositories, :github_id, unique: true
  end
end
