# frozen_string_literal: true

module CellGuardVersion
  module_function

  def label
    "1.0.0"
  end

  def git_sha
    ENV["GIT_SHA"].to_s.presence || "unknown"
  end
end
