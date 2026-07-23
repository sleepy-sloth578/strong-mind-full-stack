class AddUrlToRepositoriesAndActors < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :url, :string
    add_column :actors, :url, :string
  end
end
