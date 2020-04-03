# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class LookupGridDefinition
      def initialize(options)
        @id = options.fetch(:id)
        @lookup_key = options.fetch(:lookup_key)
        @config = LookupGridConfig.new(options)
        @params = options[:params]
        # @grid_opts = options[:grid_opts] || default_grid_opts
        @grid_opts = default_grid_opts
      end

      def default_grid_opts
        {
          lookup_url: '/lookups/%s/%s/grid',
          list_url: '/list/%s/grid',
          list_nested_url: '/list/%s/nested_grid',
          list_multi_url: '/list/%s/grid_multi',
          search_url: '/search/%s/grid',
          filter_url: '/search/%s',
          run_search_url: '/search/%s/run',
          run_to_excel_url: '/search/%s/xls'
        }
      end

      def fit_height
        @config.fit_height
      end

      def lookup_grid_caption
        caption = @config.lookup_opts[:section_caption]
        return nil if caption.nil?
        return caption unless caption.match?(/SELECT/i) && caption.match?(/\$:/)

        sql = caption
        @params.each { |k, v| sql.gsub!("$:#{k}$", v) }
        assert_sql_is_select!('caption', sql)
        DB[sql].get
      end

      # Load a YML report.
      def load_report_def(file_name)
        path = File.join(@config.root, 'grid_definitions', 'dataminer_queries', file_name.sub('.yml', '') << '.yml')
        Crossbeams::Dataminer::YamlPersistor.new(path)
      end

      def get_report(report_def)
        Crossbeams::Dataminer::Report.load(report_def)
      end

      def report
        @report ||= get_report(load_report_def(@config.dataminer_definition))
      end

      def assert_sql_is_select!(context, sql)
        raise ArgumentError, "SQL for \"#{context}\" is not a SELECT" if sql.match?(/insert |update |delete /i)
      end

      def grid_url
        @grid_opts[:lookup_url]
      end

      def grid_path
        grid_url.%([@id, @lookup_key]) # rubocop:disable Style/FormatString
      end

      # The URL that a lookup grid's selection should be saved to.
      #
      # @return [String] - the URL.
      def lookup_url
        @config.lookup_opts[:url].sub('$:id$', @params[:id].to_s)
      end

      def render_options
        res = {
          caption: caption,
          is_nested: @config.nested_grid,
          tree: @config.tree,
          lookup_key: @lookup_key,
          grid_params: @params
        }
        res
      end

      def caption
        @config.grid_caption || report.caption
      end
    end
  end
end
