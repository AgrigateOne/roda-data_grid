# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class ListGridDefinition
      def initialize(options)
        @config = ListGridConfig.new(options)
        @params = options[:params]
        @client_rule_check = (@params || {}).delete(:client_rule_check)
        @grid_opts = options[:grid_opts] || default_grid_opts
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

      def fit_height
        @config.fit_height
      end

      def multi_grid_caption
        return nil unless @config.multiselect_opts

        caption = @config.multiselect_opts[:section_caption]
        return nil if caption.nil?
        return caption unless caption.match?(/SELECT/i) && caption.match?(/\$:id\$/)

        sql = caption.sub('$:id$', @params[:id].to_s)
        assert_sql_is_select!('caption', sql)
        DB[sql].first.values.first
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

      # Check if a control should be hidden based on a client rule.
      #
      # @return [boolean] - Hide or do not hide the control.
      def hide_control_by_client_rule(page_control_def)
        return false unless page_control_def[:hide_for_client_rule] || page_control_def[:show_for_client_rule]
        return false unless @client_rule_check

        checker = ClientRuleCheck.new(@client_rule_check)
        return true if checker.should_hide?(page_control_def[:hide_for_client_rule])
        return true unless checker.should_show?(page_control_def[:show_for_client_rule])

        false
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

      # Check if the multiselect or conditions key matches a value to see if a page control should be hidden.
      #
      # @return [boolean] - Hide or do not hide the control.
      def hide_control_by_param_key(page_control_def)
        return false unless page_control_def[:hide_for_key] || page_control_def[:show_for_key]

        values = Array(page_control_def[:show_for_key]).map(&:to_sym)
        unless values.empty?
          shows = values.include?(@config.multiselect_key) || values.include?(@config.conditions_key)
          return true unless shows
        end
        values = Array(page_control_def[:hide_for_key]).map(&:to_sym)
        return false if values.empty?

        values.include?(@config.multiselect_key) || values.include?(@config.conditions_key)
      end

      def assert_sql_is_select!(context, sql)
        raise ArgumentError, "SQL for \"#{context}\" is not a SELECT" if sql.match?(/insert |update |delete /i)
      end

      def page_controls
        @config.page_control_defs.reject { |c| hide_control_by_sql(c) || hide_control_by_param_key(c) || hide_control_by_client_rule(c) }
      end

      def grid_url
        return @grid_opts[:list_nested_url] if @config.nested_grid

        if @config.multiselect_key
          @grid_opts[:list_multi_url]
        else
          @grid_opts[:list_url]
        end
      end

      def grid_path
        grid_url.%(@config.id)
      end

      # The URL that a multiselect grid's selection should be saved to.
      #
      # @return [String] - the URL.
      def multiselect_url
        @config.multiselect_opts[:url].sub('$:id$', @params[:id].to_s)
      end

      def render_options # rubocop:disable Metrics/AbcSize
        res = { caption: caption, is_nested: @config.nested_grid, tree: @config.tree, grid_params: @params }
        res.merge!(colour_key: report.external_settings[:colour_key]) if report.external_settings[:colour_key]

        if @config.multiselect_key
          res.merge!(is_multiselect: true,
                     multiselect_url: multiselect_url,
                     multiselect_key: @config.multiselect_key,
                     multiselect_params: res.delete(:grid_params),
                     can_be_cleared: @config.multiselect_opts[:can_be_cleared],
                     multiselect_save_method: @config.multiselect_opts[:multiselect_save_method])
        end
        res
      end

      def caption
        @config.grid_caption || report.caption
      end
    end
  end
end
