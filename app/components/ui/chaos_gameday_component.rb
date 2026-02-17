module Ui
  class ChaosGamedayComponent < ViewComponent::Base
    def initialize(shard:, default_duration: 20)
      @shard = shard
      @default_duration = default_duration
    end
  end
end
