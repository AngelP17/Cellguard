module Ui
  class StackBadgesComponent < ViewComponent::Base
    BADGES = [
      "Rails 7.1",
      "Hotwire",
      "Sidekiq",
      "Redis",
      "PostgreSQL",
      "Go Services",
      "ActionCable"
    ].freeze
  end
end
