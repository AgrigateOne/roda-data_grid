# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class ListGridConfig < BaseGridConfig
      attr_reader :page_control_defs, :multiselect_opts, :nested_grid, :conditions_key, :conditions, :edit_rules

      def initialize(options)
        super(options.merge(grid_type: :lists))

        @conditions_key = conditions_key_from_params(options[:params]) unless @multiselect_key
        load_config do |config|
          @edit_rules = config[:edit_rules] || {}
          @page_control_defs = config[:page_controls] || []
          assign_caption(config)
          assign_conditions(config)
          assert_edit_rules!(config)
        end
      end

      private

      def assert_edit_rules!(config)
        return unless config[:edit_rules]
        raise ArgumentError, 'Grid edit rules must include a URL' unless config[:edit_rules][:url]
        raise ArgumentError, 'Grid edit rules must include editable_fields' unless config[:edit_rules][:editable_fields]
      end

      def assign_caption(config)
        @grid_caption = @multiselect_opts[:grid_caption] if @multiselect_opts[:grid_caption] && @grid_caption.nil?
        @grid_caption = config.dig(:captions, :grid_caption) if @grid_caption.nil?

        return unless @conditions_key

        s = config.dig(:captions, :conditions, @conditions_key)
        return if s.nil?

        qs_params = Rack::Utils.parse_nested_query(@params[:query_string])
        qs_params.each { |k, v| s.gsub!("$:#{k}$", v) }
        @grid_caption = s
      end

      def assign_conditions(config)
        condition_sets = config[:conditions] || {}
        @conditions = if @multiselect_key && @multiselect_opts[:conditions]
                        condition_sets[@multiselect_opts[:conditions].to_sym]
                      elsif @conditions_key
                        condition_sets[@conditions_key]
                      else
                        []
                      end
        assert_conditions_is_array!
      end

      def assert_conditions_is_array!
        raise ArgumentError, "Expected conditions not found for key: \"#{@conditions_key || @multiselect_opts[:conditions]}\" in \"#{@id}.yml\"" if @conditions.nil?
      end

      def conditions_key_from_params(params)
        return conditions_key_from_query_string(params) if params && params[:query_string]
        return nil unless params

        params[:key] ? params[:key].to_sym : nil
      end

      def conditions_key_from_query_string(params)
        key_a = params[:query_string].split('&').select { |k| k.start_with?('key=') }
        return nil if key_a.empty?

        key_a.first.delete_prefix('key=').to_sym
      end
    end
  end
end
