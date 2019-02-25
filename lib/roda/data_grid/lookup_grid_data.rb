# frozen_string_literal: true

require 'rack'

module Crossbeams
  module DataGrid
    class LookupGridData # rubocop:disable Metrics/ClassLength
      attr_reader :config, :params

      def initialize(options)
        @deny_access = options.fetch(:deny_access)
        @lookup_key = options.fetch(:lookup_key)
        @config = LookupGridConfig.new(options)
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
        apply_params(n_params)
        col_defs = column_definitions

        {
          multiselect_ids: [],
          tree: config.tree,
          columnDefs: col_defs,
          rowDefs: dataminer_query(report.runnable_sql)
        }.to_json
      end

      def in_params(input_parameters)
        in_keys = []
        eq_sel = input_parameters.select { |p| p['op'] == '=' }.group_by { |p| p['col'] }
        eq_sel.each do |col, qp|
          in_keys << col if qp.length > 1
        end
        in_keys
      end

      def params_to_parms(params) # rubocop:disable Metrics/AbcSize
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
        report.limit  = limit_from_params(params)
        report.offset = offset_from_params(params)
        begin
          report.apply_params(parms)
        rescue StandardError => e
          return "ERROR: #{e.message}"
        end
      end

      def select_link_column
        link = if config.select_url.include?('$:id$')
                 "'#{config.select_url.sub('$:id$', "'+data.id+'")}|select'"
               else
                 "'#{config.select_url}/'+data.id+'|select'"
               end
        Crossbeams::DataGrid::ColumnDefiner.new.make_columns do |mk|
          mk.href link, 'sel_link', fetch_renderer: true
        end.first
      end

      def column_definitions(options = {}) # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
        col_defs = []
        col_defs << select_link_column

        (options[:column_set] || report.ordered_columns).each do |col|
          hs                  = { headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption }
          hs[:width]          = col.width unless col.width.nil?
          hs[:enableValue]    = true if %i[integer number].include?(col.data_type)
          hs[:enableRowGroup] = true unless config.tree || hs[:enableValue] && !col.groupable
          hs[:enablePivot]    = true unless config.tree || hs[:enableValue] && !col.groupable
          hs[:rowGroupIndex]  = col.group_by_seq if col.group_by_seq
          hs[:pinned]         = col.pinned if col.pinned
          hs[:rowGroup]       = true if col.group_by_seq

          if %i[integer number].include?(col.data_type)
            hs[:type]      = 'numericColumn'
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

          col_defs << hs
        end

        (config.calculated_columns || []).each do |raw|
          col = OpenStruct.new(raw)
          hs                  = { headerName: col.caption, field: col.name, headerTooltip: col.caption }
          hs[:width]          = col.width unless col.width.nil?
          hs[:enableValue]    = true if %i[integer number].include?(col.data_type)

          if %i[integer number].include?(col.data_type)
            hs[:type]      = 'numericColumn'
            hs[:width]     = 100 if col.width.nil? && col.data_type == :integer
            hs[:width]     = 120 if col.width.nil? && col.data_type == :number
          end
          if col.format == :delimited_1000
            hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas2'
          end
          if col.format == :delimited_1000_4
            hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas4'
          end
          parts = col.expression.split(' ')
          hs[:valueGetter] = parts.map { |p| %w[* + - /].include?(p) ? p : "data.#{p}" }.join(' ')
          col_defs.insert((col.position || 1), hs)
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

      def parse_params(options)
        params = (options[:params] || {}).merge(lookup_key: @lookup_key)
        qstr = params.delete(:query_string)
        return params if qstr.nil?
        params.merge(Rack::Utils.parse_nested_query(qstr))
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

      def dataminer_query(sql)
        DB[sql].to_a.map do |rec|
          rec.keys.each do |key|
            rec[key] = rec[key].to_f if rec[key].is_a?(BigDecimal)
          end
          rec
        end
      end

      def limit_from_params(params)
        params[:limit].to_i  unless params[:limit].nil? || params[:limit] != ''
      end

      def offset_from_params(params)
        params[:offset].to_i unless params[:offset].nil? || params[:offset] != ''
      end

      def assert_sql_is_select!(context, sql)
        raise ArgumentError, "SQL for \"#{context}\" is not a SELECT" if sql.match?(/insert |update |delete /i)
      end
    end
  end
end
