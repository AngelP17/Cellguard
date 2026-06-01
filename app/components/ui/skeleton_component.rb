# frozen_string_literal: true

module Ui
  # Skeleton placeholder for loading state.
  # Matches the rough shape of the panel it replaces.
  class SkeletonComponent < ViewComponent::Base
    SIZES = {
      text: "h-3 w-full",
      title: "h-5 w-2/3",
      metric: "h-8 w-20",
      panel: "h-32 w-full"
    }.freeze

    def initialize(kind: :text, label: nil)
      @kind = kind
      @label = label
    end

    def classes
      SIZES.fetch(@kind, SIZES[:text])
    end

    def render?
      true
    end
  end
end
