# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class BaseGridConfig
      attr_reader :id, :root, :multiselect_key, :fit_height, :grid_caption,
                  :dataminer_definition, :tree,
                  :actions, :calculated_columns, :hide_for_client, :group_default_expanded

      def initialize(options)
        @grid_type = options[:grid_type]
        @id = options.fetch(:id)
        @root = options.fetch(:root_path)
        @multiselect_key = options[:multi_key]&.to_sym
        @fit_height = options[:params]&.delete(:fit_height)
        @grid_caption = options[:grid_caption]
        @config_loader = options[:config_loader] || -> { load_config_from_file }
        @params = options[:params]
      end

      def multiselect
        !@multiselect_key.nil?
      end

      private

      def extend_hide_cols(show_cols)
        show_cols.each do |col, clients|
          @hide_for_client << col unless clients.include?(ENV['CLIENT_CODE'])
        end
      end

      def load_config # rubocop:disable Metrics/AbcSize
        config = @config_loader.call
        assign_dataminer_def(config)
        @tree = config[:tree]
        @group_default_expanded = config.dig(:grouping, :groupDefaultExpanded)
        @actions = config[:actions]
        @hide_for_client = config.dig(:hide_for_client, ENV['CLIENT_CODE']) || []
        extend_hide_cols(config.fetch(:show_for_client, {}))
        @calculated_columns = config[:calculated_columns]
        assign_multiselect(config)
        @nested_grid = !config[:nesting].nil?
        yield config if block_given?
      end

      def assign_dataminer_def(config)
        @dataminer_definition = config[:dataminer_definition]
        return unless ENV['CLIENT_CODE']

        defn = config.dig(:dataminer_client_definitions, ENV['CLIENT_CODE'])
        @dataminer_definition = defn unless defn.nil?
      end

      def assign_multiselect(config)
        raise Error, "The grid definition does not include a multiselect section for '#{@multiselect_key}'." if @multiselect_key && (config[:multiselect].nil? || config[:multiselect][@multiselect_key].nil?)

        @multiselect_opts = if @multiselect_key
                              config[:multiselect][@multiselect_key]
                            else
                              {}
                            end
      end

      def load_config_from_file
        YAML.load(read_file)
      rescue Psych::SyntaxError => e
        raise Error, "Syntax error in YAML file (#{@id.sub('.yml', '') << '.yml'}). The syntax error is: #{e.message}"
      end

      def read_file
        path = File.join(@root, 'grid_definitions', @grid_type.to_s, @id.sub('.yml', '') << '.yml')
        File.read(path)
      end
    end
  end
end
