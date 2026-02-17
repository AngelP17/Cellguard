module Ui
  class ShellComponent < ViewComponent::Base
    def initialize(title:, subtitle: nil)
      @title = title
      @subtitle = subtitle
    end
  end
end
