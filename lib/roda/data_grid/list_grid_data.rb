# frozen_string_literal: true

require 'rack'

module Crossbeams
  module DataGrid
    class ListGridData
      attr_reader :config, :params

      def initialize(options)
        @deny_access = options.fetch(:deny_access)
        @config = ListGridConfig.new(options)
        @params = parse_params(options)
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
        @report ||= get_report(load_report_def(config.dataminer_definition))
      end

      # Column and row definitions for a list grid.
      #
      # @return [JSON] - a Hash containing row and column definitions.
      def list_rows
        n_params = { json_var: conditions.to_json }
        apply_params(n_params) unless n_params.nil? || n_params.empty?
        col_defs = column_definitions
        multiselect_ids = config.multiselect ? preselect_ids : []

        {
          multiselect_ids: multiselect_ids,
          tree: config.tree,
          columnDefs: col_defs,
          rowDefs:    dataminer_query(report.runnable_sql)
        }.to_json
      end

      def list_nested_rows
        raise Roda::RodaPlugins::DataGrid::Error, 'Nested rows implementation is on hold'
      end

      def in_params(input_parameters)
        in_keys = []
        eq_sel = input_parameters.select { |p| p['op'] == '=' }.group_by { |p| p['col'] }
        eq_sel.each do |col, qp|
          in_keys << col if qp.length > 1
        end
        in_keys
      end

      def params_to_parms(params)
        input_parameters = ::JSON.parse(params[:json_var]) || []
        parms = []
        # Check if this should become an IN parmeter (list of equal checks for a column.
        in_keys = in_params(input_parameters)
        in_sets = {}

        input_parameters.each do |in_param|
          col = in_param['col']
          if in_keys.include?(col)
            in_sets[col] ||= []
            in_sets[col] << in_param['val']
            next
          end
          param_def = report.parameter_definition(col)
          raise Roda::RodaPlugins::DataGrid::Error, "There is no parameter for this grid query named \"#{col}\"" if param_def.nil?
          val = if in_param['op'] == 'between'
                  [in_param['val'], in_param['val_to']]
                else
                  in_param['val']
                end
          parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], val, param_def.data_type))
        end
        in_sets.each do |col, vals|
          param_def = report.parameter_definition(col)
          parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new('in', vals, param_def.data_type))
        end
        parms
      end

      def apply_params(params)
        # { "col"=>"users.department_id", "op"=>"=", "opText"=>"is", "val"=>"17", "text"=>"Finance", "caption"=>"Department" }
        parms = params_to_parms(params)
        report.limit  = params[:limit].to_i  unless params[:limit].nil? || params[:limit] != ''
        report.offset = params[:offset].to_i unless params[:offset].nil? || params[:offset] != ''
        begin
          report.apply_params(parms)
        rescue StandardError => e
          return "ERROR: #{e.message}"
        end
      end

      def column_definitions(options = {})
        col_defs = []

        # TEST: multiselect
        if config.multiselect
          hs = {
            headerName: '',
            colId: 'theSelector',
            pinned: 'left',
            width: 45,
            headerCheckboxSelection: true,
            headerCheckboxSelectionFilteredOnly: true,
            checkboxSelection: true,
            suppressMenu: true,   suppressSorting: true,   suppressMovable: true,
            suppressFilter: true, enableRowGroup: false,   enablePivot: false,
            enableValue: false,   suppressCsvExport: true, suppressToolPanel: true
          }
          col_defs << hs
        end

        # Actions
        if config.actions
          this_col = make_subitems(config.actions)
          hs = { headerName: '', pinned: 'left',
                 width: 60,
                 suppressMenu: true,   suppressSorting: true,   suppressMovable: true,
                 suppressFilter: true, enableRowGroup: false,   enablePivot: false,
                 enableValue: false,   suppressCsvExport: true, suppressToolPanel: true,
                 valueGetter: this_col.to_json.to_s,
                 colId: 'action_links',
                 cellRenderer: 'crossbeamsGridFormatters.menuActionsRenderer' }
          col_defs << hs
        end

        (options[:column_set] || report.ordered_columns).each do |col| # rubocop:disable Metrics/BlockLength
          hs                  = { headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption }
          hs[:width]          = col.width unless col.width.nil?
          hs[:enableValue]    = true if %i[integer number].include?(col.data_type)
          hs[:enableRowGroup] = true unless config.tree || hs[:enableValue] && !col.groupable
          hs[:enablePivot]    = true unless config.tree || hs[:enableValue] && !col.groupable
          hs[:rowGroupIndex]  = col.group_by_seq if col.group_by_seq
          # hs[:pinned]         = 'left' if col.group_by_seq # if col.pinned || col.group_by_seq
          hs[:rowGroup]       = true if col.group_by_seq
          # hs[:valueGetter]    = 'blankWhenNull'

          if %i[integer number].include?(col.data_type)
            hs[:cellClass] = 'grid-number-column'
            hs[:width]     = 100 if col.width.nil? && col.data_type == :integer
            hs[:width]     = 120 if col.width.nil? && col.data_type == :number
          end
          if col.format == :delimited_1000
            hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas2'
          end
          if col.format == :delimited_1000_4
            hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas4'
          end
          if col.data_type == :boolean
            hs[:cellRenderer] = 'crossbeamsGridFormatters.booleanFormatter'
            hs[:cellClass]    = 'grid-boolean-column'
            hs[:width]        = 100 if col.width.nil?
          end

          if options[:expands_nested_grid] && options[:expands_nested_grid] == col.name
            hs[:cellRenderer]       = 'group' # This column will have the expand/contract controls.
            hs[:cellRendererParams] = { suppressCount: true } # There is always one child (a sub-grid), so hide the count.
            hs.delete(:enableRowGroup) # ... see if this helps?????
            hs.delete(:enablePivot) # ... see if this helps?????
          end

          # hs[:cellClassRules] = { "grid-row-red": "x === 'Fred'" } if col.name == 'author'

          col_defs << hs
        end
        col_defs
      end

      def conditions
        return nil if config.conditions.empty?

        config.conditions.map do |condition|
          if condition[:val].to_s.include?('$')
            parameterize_value(condition)
          else
            condition
          end
        end
      end

      private

      # Build action column items recursively.
      def make_subitems(actions, level = 0)
        this_col = []
        cnt = 0
        actions.each do |action| # rubocop:disable Metrics/BlockLength
          if action[:separator]
            cnt += 1
            this_col << { text: "sep#{level}#{cnt}", is_separator: true }
            next
          end
          if action[:submenu]
            this_col << { text: action[:submenu][:text], is_submenu: true, items: make_subitems(action[:submenu][:items], level + 1) }
            next
          end

          # Check if user is authorised for this action:
          next if action[:auth] && @deny_access.call(action[:auth][:function], action[:auth][:program], action[:auth][:permission])

          keys = action[:url].split(/\$/).select { |key| key.start_with?(':') }
          url  = action[:url]
          keys.each_with_index { |key, index| url.gsub!("$#{key}$", "$col#{index}$") }
          link_h = {
            text: action[:text] || 'link',
            url: url
          }
          keys.each_with_index { |key, index| link_h["col#{index}".to_sym] = key.sub(':', '') }
          if action[:is_delete]
            link_h[:prompt] = 'Are you sure?'
            link_h[:method] = 'delete'
          end
          link_h[:icon] = action[:icon] if action[:icon]
          link_h[:prompt] = action[:prompt] if action[:prompt]
          link_h[:title] = action[:title] if action[:title]
          link_h[:title_field] = action[:title_field] if action[:title_field]
          link_h[:popup] = action[:popup] if action[:popup]
          link_h[:hide_if_null] = action[:hide_if_null] if action[:hide_if_null]
          link_h[:hide_if_present] = action[:hide_if_present] if action[:hide_if_present]
          link_h[:hide_if_true] = action[:hide_if_true] if action[:hide_if_true]
          link_h[:hide_if_false] = action[:hide_if_false] if action[:hide_if_false]
          this_col << link_h
        end
        this_col
      end

      def parse_params(options)
        return nil unless options[:params]
        qstr = options[:params].delete(:query_string)
        return options[:params] if qstr.nil?
        options[:params].merge(Rack::Utils.parse_nested_query(qstr))
      end

      def parameterize_value(condition)
        val = condition[:val]
        @params.each { |k, v| val.gsub!("$:#{k}$", v) }
        condition[:val] = val
        if condition[:op].match?(/in/i)
          condition[:val] = condition_value_as_array(val)
        end
        condition
      end

      def condition_value_as_array(val)
        return val if val.is_a?(Array)
        return Array(val) unless val.is_a?(String)
        val.sub('[', '').sub(']', '').split(',').map(&:strip)
      end

      # For multiselect grids, get the ids that should be preselected in the grid.
      #
      # @return [Array] - a list of ids (can be empty)
      def preselect_ids
        return [] if config.multiselect_opts[:preselect].nil? || params.nil?
        sql = config.multiselect_opts[:preselect]
        params.each { |k, v| sql.gsub!("$:#{k}$", v.to_s) }
        assert_sql_is_select!('preselect', sql)
        DB[sql].map { |r| r.values.first }
      end

      def dataminer_query(sql)
        DB[sql].to_a.map do |rec|
          rec.keys.each do |key|
            rec[key] = rec[key].to_f if rec[key].is_a?(BigDecimal)
          end
          rec
        end
      end

      def assert_sql_is_select!(context, sql)
        raise ArgumentError, "SQL for \"#{context}\" is not a SELECT" if sql.match?(/insert |update |delete /i)
      end
    end
  end
end
