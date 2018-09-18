# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class ListGridDefinition # rubocop:disable Metrics/ClassLength
      attr_reader :fit_height

      def initialize(options)
        @id = options.fetch(:id)
        @root = options.fetch(:root_path)
        @multiselect_key = options[:multi_key]&.to_sym
        @params = options[:params]
        @fit_height = @params&.delete(:fit_height)
        @grid_opts = options[:grid_opts] || default_grid_opts
        @grid_caption = options[:grid_caption]
        @config_loader = options[:config_loader] || -> { load_config_from_file }
        load_config
      end

      def default_grid_opts
        {
          list_url: '/list/%s/grid',
          list_nested_url: '/list/%s/nested_grid',
          list_multi_url: '/list/%s/grid_multi',
          search_url: '/search/%s/grid',
          filter_url: '/search/%s',
          run_search_url: '/search/%s/run',
          run_to_excel_url: '/search/%s/xls'
        }
      end

      def load_config_from_file
        YAML.load(read_file)
      end

      def read_file
        path = File.join(@root, 'grid_definitions', 'lists', @id.sub('.yml', '') << '.yml')
        File.read(path)
      end

      def load_config
        # tree
        # page_controls
        # dataminer_definition
        # conditions |==> Not now (only required for grid)
        # multiselect
        # nesting
        # actions |==> not now
        config = @config_loader.call
        @dataminer_definition = config[:dataminer_definition]
        @tree = config[:tree]
        @page_control_defs = config[:page_controls] || []
        @multiselect_opts = if @multiselect_key
                              config[:multiselect][@multiselect_key]
                            else
                              {}
                            end
        @nested_grid = !config[:nesting].nil?
        @grid_caption = @multiselect_opts[:grid_caption] if @multiselect_opts[:grid_caption] && @grid_caption.nil?
        @grid_caption = config[:grid_caption] if @grid_caption.nil?
        # condition_sets = config[:conditions] || {}
        # @conditions = if @multiselect_key && @multiselect_opts[:conditions]
        #                 condition_sets[@multiselect_opts[:conditions]]
        #               elsif @conditions_key
        #                 condition_sets[@conditions_key]
        #               else
        #                 []
        #               end
      end

      def multi_grid_caption
        return nil unless @multiselect_opts
        caption = @multiselect_opts[:section_caption]
        return nil if caption.nil?
        return caption unless caption.match?(/SELECT/i) && caption.match?(/\$:id\$/)
        sql = caption.sub('$:id$', @params[:id].to_s)
        assert_sql_is_select!('caption', sql)
        DB[sql].first.values.first
      end

      # Load a YML report.
      def load_report_def(file_name)
        path = File.join(@root, 'grid_definitions', 'dataminer_queries', file_name.sub('.yml', '') << '.yml')
        Crossbeams::Dataminer::YamlPersistor.new(path)
      end

      def get_report(report_def)
        Crossbeams::Dataminer::Report.load(report_def)
      end

      def report
        @report ||= get_report(load_report_def(@dataminer_definition))
      end

      # Run the given SQL to see if a page control should be hidden.
      #
      # @return [boolean] - Hide or do not hide the control.
      def hide_control_by_sql(page_control_def)
        return false unless page_control_def[:hide_if_sql_returns_true]
        sql = page_control_def[:hide_if_sql_returns_true]
        assert_sql_is_select!('hide_if_sql_returns_true', sql)
        DB[sql].get
      end

      def assert_sql_is_select!(context, sql)
        raise ArgumentError, "SQL for \"#{context}\" is not a SELECT" if sql.match?(/insert |update |delete /i)
      end

      def page_controls
        @page_control_defs.reject { |c| hide_control_by_sql(c) }
      end

      def grid_url
        return @grid_opts[:list_nested_url] if @nested_grid

        if @multiselect_key
          @grid_opts[:list_multi_url]
        else
          @grid_opts[:list_url]
        end
      end

      def grid_path
        grid_url.%(@id)
      end

      # The URL that a multiselect grid's selection should be saved to.
      #
      # @return [String] - the URL.
      def multiselect_url
        @multiselect_opts[:url].sub('$:id$', @params[:id].to_s)
      end

      def render_options
        res = { caption: caption, is_nested: @nested_grid, tree: @tree, grid_params: @params }

        if @multiselect_key
          res.merge!(is_multiselect: true,
                     multiselect_url: multiselect_url,
                     multiselect_key: @multiselect_key,
                     multiselect_params: res.delete(:grid_params),
                     can_be_cleared: @multiselect_opts[:can_be_cleared],
                     multiselect_save_method: @multiselect_opts[:multiselect_save_method])
        end
        res
      end

      def caption
        @grid_caption || report.caption
      end
    end
  end
end
