# frozen_string_literal: true

# Shared API concerns for CellGuard production hardening.
#
# - TokenGuard: rejects mutation requests without a valid CELLGUARD_TOKEN
#   outside of development/demo modes.
# - StructuredErrors: renders consistent JSON error responses without
#   leaking raw exception messages.
# - RequestAudit: records a lightweight audit trail for privileged
#   operations (actor/token label, endpoint, shard, status, timestamp).
module Api
  module TokenGuard
    extend ActiveSupport::Concern

    class TokenMissing < StandardError; end
    class TokenInvalid < StandardError; end

    included do
      rescue_from TokenMissing, with: ->(_e) { render_token_error(:unauthorized, "token_required") }
      rescue_from TokenInvalid, with: ->(_e) { render_token_error(:unauthorized, "token_invalid") }
    end

    private

    def require_admin_token!
      return if Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"

      provided = request.headers["X-CELLGUARD-TOKEN"].to_s
      expected = ENV["CELLGUARD_TOKEN"].to_s

      raise TokenMissing, "missing token" if provided.empty?
      raise TokenMissing, "missing token" if expected.empty?
      raise TokenInvalid, "invalid token" unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
    end

    def token_actor_label
      return "demo" if Rails.env.development? || ENV["ALLOW_DEMO_ENDPOINTS"] == "true"

      request.headers["X-CELLGUARD-TOKEN"].to_s.empty? ? "anonymous" : "admin"
    end

    def render_token_error(status, code)
      render json: { error: code, message: humanize_error(code) }, status: status
    end

    def humanize_error(code)
      case code
      when "token_required" then "X-CELLGUARD-TOKEN header is required for this operation."
      when "token_invalid" then "X-CELLGUARD-TOKEN header is invalid."
      else code.to_s.humanize
      end
    end
  end

  module StructuredErrors
    extend ActiveSupport::Concern

    included do
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      rescue_from ActionController::BadRequest, with: :render_bad_request
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
      rescue_from JSON::ParserError, with: :render_bad_request
      rescue_from StandardError, with: :render_internal_error if Rails.env.production?
    end

    private

    def render_bad_request(exception)
      render json: { error: "bad_request", message: exception.message }, status: :bad_request
    end

    def render_not_found(exception)
      render json: { error: "not_found", message: exception.message }, status: :not_found
    end

    def render_unprocessable(exception)
      render json: { error: "unprocessable", message: exception.message, details: exception.record&.errors&.as_json }, status: :unprocessable_entity
    end

    def render_internal_error(exception)
      Rails.logger.error("[#{self.class.name}] #{exception.class}: #{exception.message}")
      render json: { error: "internal_error", message: "An unexpected error occurred. Check server logs." }, status: :internal_server_error
    end
  end

  module RequestAudit
    extend ActiveSupport::Concern

    private

    def audit_request!(action:, shard: nil, justification: nil, metadata: {})
      return unless shard.is_a?(Shard) || (shard.respond_to?(:name) && shard.name.present?)

      AuditLog.create!(
        shard: shard,
        actor: request_actor,
        action: action,
        justification: justification || "#{request.method} #{request.path}",
        metadata: audit_metadata.merge(metadata)
      )
    rescue StandardError => e
      Rails.logger.warn("[RequestAudit] Failed to record audit: #{e.message}")
    end

    def request_actor
      token_actor_label.presence || "operator"
    end

    def audit_metadata
      {
        method: request.method,
        path: request.path,
        remote_ip: request.remote_ip,
        user_agent: request.user_agent,
        at: Time.current.iso8601
      }
    end
  end
end
