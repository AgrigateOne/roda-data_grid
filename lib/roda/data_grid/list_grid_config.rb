# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class ListGridConfig
      attr_reader :id, :root, :multiselect_key, :fit_height, :grid_caption,
                  :dataminer_definition, :tree, :page_control_defs,
                  :multiselect_opts, :nested_grid, :conditions_key, :conditions, :actions,
                  :calculated_columns, :edit_rules, :hide_for_client

      def initialize(options)
        @id = options.fetch(:id)
        @root = options.fetch(:root_path)
        @multiselect_key = options[:multi_key]&.to_sym
        @fit_height = options[:params]&.delete(:fit_height)
        @conditions_key = conditions_key_from_params(options[:params]) unless @multiselect_key
        @grid_caption = options[:grid_caption]
        @config_loader = options[:config_loader] || -> { load_config_from_file }
        @params = options[:params]
        load_config
      end

      def multiselect
        !@multiselect_key.nil?
      end

      private

      def load_config # rubocop:disable Metrics/AbcSize
        config = @config_loader.call
        assign_dataminer_def(config)
        @tree = config[:tree]
        @actions = config[:actions]
        @edit_rules = config[:edit_rules] || {}
        @hide_for_client = config.dig(:hide_for_client, ENV['CLIENT_CODE']) || []
        @calculated_columns = config[:calculated_columns]
        @page_control_defs = config[:page_controls] || []
        assign_multiselect(config)
        @nested_grid = !config[:nesting].nil?
        assign_caption(config)
        assign_conditions(config)
        assert_edit_rules!(config)
      end

      def assign_dataminer_def(config)
        @dataminer_definition = config[:dataminer_definition]
        return unless ENV['CLIENT_CODE']

        defn = config.dig(:dataminer_client_definitions, ENV['CLIENT_CODE'])
        @dataminer_definition = defn unless defn.nil?
      end

      def assert_edit_rules!(config)
        return unless config[:edit_rules]
        raise ArgumentError, 'Grid edit rules must include a URL' unless config[:edit_rules][:url]
        raise ArgumentError, 'Grid edit rules must include editable_fields' unless config[:edit_rules][:editable_fields]
      end

      def assign_multiselect(config)
        raise Error, "The grid definition does not include a multiselect section for '#{@multiselect_key}'." if @multiselect_key && (config[:multiselect].nil? || config[:multiselect][@multiselect_key].nil?)

        @multiselect_opts = if @multiselect_key
                              config[:multiselect][@multiselect_key]
                            else
                              {}
                            end
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

      def load_config_from_file
        YAML.load(read_file)
      rescue Psych::SyntaxError => e
        raise Error, "Syntax error in YAML file (#{@id.sub('.yml', '') << '.yml'}). The syntax error is: #{e.message}"
      end

      def read_file
        path = File.join(@root, 'grid_definitions', 'lists', @id.sub('.yml', '') << '.yml')
        File.read(path)
      end
    end
  end
end
