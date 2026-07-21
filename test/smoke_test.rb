require "test_helper"

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
