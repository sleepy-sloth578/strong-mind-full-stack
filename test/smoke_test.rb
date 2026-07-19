require "test_helper"

# Scaffold smoke tests: prove the app boots, the database is reachable, and the
# Solid Queue schema is present. These are placeholders until the real
# extraction/dedup/ingest tests land alongside the pipeline (see CLAUDE.md).
class SmokeTest < ActiveSupport::TestCase
  test "application is API-only" do
    assert App::Application.config.api_only
  end

  test "database connection is active" do
    assert ActiveRecord::Base.connection.active?
  end

  test "solid queue schema is loaded" do
    assert_includes ActiveRecord::Base.connection.tables, "solid_queue_jobs"
  end
end
