module Ui
  class ShellComponent < ViewComponent::Base
    include HeroiconsHelper

    def initialize(title:, subtitle: nil)
      @title = title
      @subtitle = subtitle
    end

    def nav_items
      [
        { label: "Dashboard", href: "/dashboard", icon: "squares-2x2", active: active_path?("/dashboard") },
        { label: "Incidents", href: "/incidents", icon: "exclamation-triangle", active: active_path?("/incidents") },
        { label: "Runbooks", href: "/runbooks/gameday", icon: "book-open", active: active_path?("/runbooks") }
      ]
    end

    def nav_link_classes(active)
      active ? "cg-top-nav__link is-active" : "cg-top-nav__link"
    end

    private

    def active_path?(prefix)
      path = helpers.request&.path.to_s
      return true if path == prefix

      path.start_with?("#{prefix}/")
    end
  end
end
