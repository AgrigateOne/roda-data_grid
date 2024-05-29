# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class SearchGridConfig < BaseGridConfig
      attr_reader :multiselect_opts, :nested_grid, :conditions_key, :conditions, :edit_rules,
                  :fixed_parameters, :selected_parameter_list

      def initialize(options)
        super(options.merge(grid_type: :searches))

        load_config do |config|
          @page_control_defs = config[:page_controls] || []
          assign_caption(config)
          @fixed_parameters = config[:fixed_parameters]
          @selected_parameter_list = config[:selected_parameter_list] || []
        end
      end

      private

      def assign_caption(config)
        @grid_caption = config.dig(:captions, :grid_caption) if @grid_caption.nil?
      end
    end
  end
end
