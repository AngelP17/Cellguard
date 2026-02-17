module Ui
  class BudgetMeterComponent < ViewComponent::Base
    def initialize(remaining:)
      @remaining = [[remaining.to_f, 0.0].max, 1.0].min
    end

    def pct
      (@remaining * 100.0).round(2)
    end
  end
end
