# The event payload provides the API URL for each repo/actor (repo.url,
# actor.url). We persist it so enrichment can follow the payload-provided link
# (Story 3) rather than reconstructing the endpoint.
class AddUrlToRepositoriesAndActors < ActiveRecord::Migration[8.1]
  def change
    add_column :repositories, :url, :string
    add_column :actors, :url, :string
  end
end
