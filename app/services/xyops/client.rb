# frozen_string_literal: true

module Xyops
  # Xyops::Client - the single interface for the fabric adapter.
  #
  # Per spec: one interface that supports simulator (for demo when real xyOps API
  # contract is not fully public) + real HTTP mode.
  #
  # Real xyOps is self-hosted (Docker). Only this class changes if the internal
  # API differs. Everything else in CellGuard (runner, agents, controllers, UI,
  # gameday) stays functional.
  #
  # Public contract (as specified):
  #   client = Xyops::Client.new(connection: XyopsConnection.primary)
  #   client.healthy?
  #   client.workflow_run(id)
  #   client.trigger_remediation!(workflow:, payload:)
  class Client
    class Error < StandardError; end

    API_PREFIX = "/api/app"
    API_SUFFIX = "/v1"

    attr_reader :connection

    def initialize(connection: XyopsConnection.primary, http_client: nil)
      @connection = connection || XyopsConnection.ensure_default_stub!
      @http_client = http_client # injectable for tests
    end

    def healthy?
      return Simulator.healthy? if simulator?

      begin
        resp = perform("get_servers")
        !!(resp && (resp["code"] == 0 || resp["servers"]))
      rescue StandardError
        false
      end
    end

    # Back compat for existing tests / calls
    def health
      if simulator?
        { status: "ok", mode: "simulator", version: "0.9.0-sim", checked_at: Time.current.iso8601 }
      else
        begin
          resp = perform("get_servers")
          { status: "ok", mode: "real", servers: (resp["servers"] || {}).keys.first(3), checked_at: Time.current.iso8601 }
        rescue Error => e
          { status: "degraded", mode: "real", error: e.message, checked_at: Time.current.iso8601 }
        end
      end
    end


    def workflow_run(id)
      return Simulator.workflow_run(id) if simulator?

      begin
        resp = perform("get_job", { id: id })
        job = resp["job"] || resp
        normalize_run(job, id)
      rescue StandardError
        nil
      end
    end

    def trigger_remediation!(workflow:, payload: {})
      return Simulator.trigger_remediation!(workflow: workflow, payload: payload) if simulator?

      begin
        resp = perform("run_event", { id: workflow }.merge(payload || {}), method: :post)
        {
          status: "queued",
          workflow: workflow,
          run_id: resp["id"],
          raw: resp
        }
      rescue StandardError => e
        { status: "error", workflow: workflow, error: e.message }
      end
    end

    # --- Back-compat / internal helpers used by existing code (kept working) ---

    def stub_mode?
      simulator?
    end

    def list_workflows(**)
      return Simulator.workflows(**) if simulator?
      # real would call get_events etc.
      []
    end

    def get_workflow_run(external_id:)
      workflow_run(external_id)
    end

    def trigger_workflow(name:, params: {}, approval_token: nil)
      trigger_remediation!(workflow: name, payload: (params || {}).merge(approval_token: approval_token))
    end

    def recent_alerts(**)
      return Simulator.recent_alerts(**) if simulator?
      []
    end

    def capture_snapshot(**)
      return Simulator.capture_snapshot(**) if simulator?
      { server_id: "unknown", captured_at: Time.current }
    end

    def job_history(**)
      return Simulator.job_history(**) if simulator?
      []
    end

    private

    def simulator?
      @connection.nil? || @connection.mode == "simulator"
    end

    def perform(name, params = {}, method: :get)
      base = @connection.real_base_url
      raise Error, "No real base_url on connection" if base.blank?

      api_key = @connection.api_key
      raise Error, "api_key required for real xyOps" if api_key.blank?

      url = "#{base.chomp('/') }#{API_PREFIX}/#{name}#{API_SUFFIX}"

      if @http_client.respond_to?(:call)
        raw = @http_client.call(method, url, params)
        return handle_response(raw)
      end

      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 3
      http.read_timeout = 6

      req = if method == :post
              r = Net::HTTP::Post.new(uri.request_uri)
              r["Content-Type"] = "application/json"
              r["X-API-Key"] = api_key
              r.body = params.to_json
              r
            else
              r = Net::HTTP::Get.new(uri.request_uri)
              r["X-API-Key"] = api_key
              r
            end

      res = http.request(req)
      body = begin
               JSON.parse(res.body)
             rescue
               { "code" => -1, "description" => res.body.to_s[0, 200] }
             end
      handle_response(body)
    end

    def handle_response(body)
      code = body["code"]
      if code == 0 || code.nil?
        body
      else
        raise Error, "xyOps error #{code}: #{body['description'] || body['error']}"
      end
    end

    def normalize_run(job, id)
      {
        id: id,
        workflow: job["event_title"] || job["title"] || "unknown",
        status: (job["status"] || "running").to_s.downcase,
        server: job["target"] || job["server_id"] || "unknown",
        started_at: job["started"] ? Time.at(job["started"]) : nil,
        completed_at: job["completed"] ? Time.at(job["completed"]) : nil,
        metadata: job
      }
    end
  end
end

