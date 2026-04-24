module Ui
  class LandingHeroComponent < ViewComponent::Base
    def initialize(
      title: "CellGuard",
      headline: "Deploy decisions backed by live reliability evidence.",
      subtitle: "Reliability control plane for release safety.",
      supporting_copy: "Prevent bad deploys with policy-as-code, error budgets, chaos drills, and audited overrides."
    )
      @title = title
      @headline = headline
      @subtitle = subtitle
      @supporting_copy = supporting_copy
    end
  end
end
