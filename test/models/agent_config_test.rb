require "test_helper"

class AgentConfigTest < ActiveSupport::TestCase
  test "uses default values when no override exists" do
    assert_equal true, AgentConfig.get_bool("agents_enabled")
  end

  test "db override takes precedence" do
    AgentConfig.set!("budget_guard_enabled", "false")

    assert_equal false, AgentConfig.enabled?("budget_guard")
  end
end
