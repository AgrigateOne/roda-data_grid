# frozen_string_literal: true

module Crossbeams
  module DataGrid
    # Pass string representations of client rules to a proc to be evaluated.
    class ClientRuleCheck
      def initialize(checker)
        @checker = checker
      end

      # If any of the client rules return true, hide the control/action.
      def should_hide?(conditions)
        return false if conditions.nil?

        hide = false
        conditions.split(';').each do |test|
          args = test.split('.')
          # If needed, this could be expanded to parse (args) as well...
          hide = true if @checker.call(args)
        end
        hide
      end

      def should_show?(conditions)
        return true if conditions.nil?

        show = false
        conditions.split(';').each do |test|
          args = test.split('.')
          show = true if @checker.call(args)
        end
        show
      end
    end
  end
end
