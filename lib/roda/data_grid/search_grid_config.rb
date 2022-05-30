# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class SearchGridConfig < BaseGridConfig
      attr_reader :multiselect_opts, :nested_grid, :conditions_key, :conditions, :edit_rules

      def initialize(options)
        super(options.merge(grid_type: :searches))

        load_config do |config|
          # @edit_rules = config[:edit_rules] || {}
          @page_control_defs = config[:page_controls] || []
          assign_caption(config)
          # assert_edit_rules!(config)
        end
      end

      private

      # def assert_edit_rules!(config)
      #   return unless config[:edit_rules]
      #   raise ArgumentError, 'Grid edit rules must include a URL' unless config[:edit_rules][:url]
      #   raise ArgumentError, 'Grid edit rules must include editable_fields' unless config[:edit_rules][:editable_fields]
      # end

      # def assign_multiselect(config)
      #   raise Error, "The grid definition does not include a multiselect section for '#{@multiselect_key}'." if @multiselect_key && (config[:multiselect].nil? || config[:multiselect][@multiselect_key].nil?)
      #
      #   @multiselect_opts = if @multiselect_key
      #                         config[:multiselect][@multiselect_key]
      #                       else
      #                         {}
      #                       end
      # end

      def assign_caption(config)
        # @grid_caption = @multiselect_opts[:grid_caption] if @multiselect_opts[:grid_caption] && @grid_caption.nil?
        @grid_caption = config.dig(:captions, :grid_caption) if @grid_caption.nil?

        # return unless @conditions_key
        #
        # s = config.dig(:captions, :conditions, @conditions_key)
        # return if s.nil?
        #
        # qs_params = Rack::Utils.parse_nested_query(@params[:query_string])
        # qs_params.each { |k, v| s.gsub!("$:#{k}$", v) }
        # @grid_caption = s
      end
    end
  end
end
