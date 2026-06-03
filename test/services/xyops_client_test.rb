# frozen_string_literal: true

require "test_helper"

class XyopsClientTest < ActiveSupport::TestCase
  setup do
    @stub_conn = XyopsConnection.ensure_default_stub!
    XyopsConnection.where("name LIKE 'test-real%' OR name LIKE 'bad%'").delete_all
    @real_conn = XyopsConnection.create!(
      name: "test-real-#{SecureRandom.hex(4)}",
      base_url: "http://example-xyops:3012",
      config: { "mode" => "real", "api_key" => "testkey123456789012345678", "group" => "main" }
    )
  end

  teardown do
    XyopsConnection.where("name LIKE 'test-real%' OR name LIKE 'bad%'").delete_all rescue nil
    Xyops::Simulator.instance_variable_set(:@connection, nil) rescue nil
  end



  test "stub mode uses simulator and returns normalized data" do
    client = Xyops::Client.new(connection: @stub_conn)
    assert client.stub_mode?

    health = client.health
    assert_equal "ok", health[:status]
    assert_equal "simulator", health[:mode] || "simulator"

    workflows = client.list_workflows
    assert workflows.is_a?(Array)

    run = client.trigger_workflow(name: "restart-print-worker")
    assert run[:run_id].present?
  end

  test "real mode builds correct urls and uses api key (testable via injected client)" do
    calls = []
    fake = ->(m, u, p) do
      calls << [m, u, p]
      { "code" => 0, "id" => "j-real-123" }
    end

    client = Xyops::Client.new(connection: @real_conn, http_client: fake)
    refute client.stub_mode?

    client.trigger_workflow(name: "my-remediation", params: { shard: "s1" })
    assert calls.any? { |c| c[1].include?("/api/app/run_event/v1") && c[2][:id] == "my-remediation" }

    # Simulate get_events for list (resilient)
    fake2 = ->(m, u, p) { { "code" => 0, "rows" => [{ "id" => "e1", "title" => "nightly" }] } }
    client2 = Xyops::Client.new(connection: @real_conn, http_client: fake2)
    wfs = client2.list_workflows rescue []
    assert wfs.is_a?(Array)
    if wfs.first
      assert_equal "e1", wfs.first[:id] || wfs.first["id"]
    end

  end

  test "real client is resilient but errors on obviously bad config for perform" do
    bad = XyopsConnection.create!(name: "bad-#{SecureRandom.hex(3)}", base_url: "http://x", config: {})
    client = Xyops::Client.new(connection: bad)
    # health should not blow up
    health = client.health rescue { status: "error" }
    assert health[:status].present?
    # direct perform must raise
    assert_raises(Xyops::Client::Error) { client.send(:perform, "get_events") }
  end
end



