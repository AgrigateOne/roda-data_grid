# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class LookupGridConfig
      attr_reader :id, :root, :lookup_key, :fit_height, :grid_caption,
                  :dataminer_definition, :tree, :page_control_defs,
                  :multiselect_opts, :nested_grid, :conditions_key, :conditions, :actions,
                  :calculated_columns, :lookup_opts, :select_url

      def initialize(options)
        @id = options.fetch(:id)
        @lookup_key = options.fetch(:lookup_key).to_sym
        @root = options.fetch(:root_path)
        # @multiselect_key = options[:multi_key]&.to_sym
        @fit_height = options[:params]&.delete(:fit_height)
        # @conditions_key = conditions_key_from_params(options[:params]) unless @multiselect_key
        @grid_caption = options[:grid_caption]
        @config_loader = options[:config_loader] || -> { load_config_from_file }
        load_config
      end

      private

      def load_config # rubocop:disable Metrics/AbcSize
        config = @config_loader.call
        @dataminer_definition = config[:dataminer_definition]
        @tree = config[:tree]
        @actions = config[:actions]
        @calculated_columns = config[:calculated_columns]
        @page_control_defs = config[:page_controls] || []
        @lookup_opts = config[:lookups][@lookup_key]
        @select_url = @lookup_opts.fetch(:url).chomp('/')
        @nested_grid = !config[:nesting].nil?
        assign_caption(config)
        assign_conditions(config)
      end

      def assign_caption(config)
        @grid_caption = @lookup_opts[:grid_caption] if @lookup_opts[:grid_caption] && @grid_caption.nil?
        @grid_caption = config[:grid_caption] if @grid_caption.nil?
      end

      def assign_conditions(config)
        condition_sets = config[:conditions] || {}
        @conditions = if @lookup_key && @lookup_opts[:conditions]
                        condition_sets[@lookup_opts[:conditions].to_sym]
                      else
                        []
                      end
        assert_conditions_is_array!
      end

      def assert_conditions_is_array!
        raise ArgumentError, "Expected conditions not found for key: \"#{@lookup_key}\" in \"#{@id}.yml\"" if @conditions.nil?
      end

      def load_config_from_file
        YAML.load(read_file)
      end

      def read_file
        path = File.join(@root, 'grid_definitions', 'lookups', @id.sub('.yml', '') << '.yml')
        File.read(path)
      end
    end
  end
end
