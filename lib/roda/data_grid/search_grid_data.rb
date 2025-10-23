# frozen_string_literal: true

require 'rack'

module Crossbeams
  module DataGrid
    class SearchGridData
      include GridColdefBuilder

      attr_reader :config, :params

      def initialize(options)
        @deny_access = options.fetch(:deny_access)
        @has_permission = options.fetch(:has_permission)
        @client_rule_check = options.fetch(:client_rule_check)
        @config = SearchGridConfig.new(options)
        @params = parse_params(options)
        @multi_dimensional_arrays = []
        assert_actions_ok!
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
        # n_params = { json_var: conditions.to_json }
        # n_params = ::JSON.parse(params[:json_var]) || []
        apply_params(params)

        {
          multiselect_ids: multiselect_ids,
          # fieldUpdateUrl: config.edit_rules[:url],
          tree: config.tree,
          columnDefs: column_definitions,
          rowDefs: dataminer_query(report.runnable_sql)
        }.to_json
      end

      # def debug_grid
      #   cond = conditions
      #   n_params = { json_var: cond.to_json }
      #   apply_params(n_params)
      #
      #   {
      #     caption: report.caption,
      #     multiselect_ids: multiselect_ids,
      #     fieldUpdateUrl: config.edit_rules[:url],
      #     tree: config.tree,
      #     fit_height: config.fit_height,
      #     root: config.root,
      #     columnDefs: column_definitions,
      #     sql: report.runnable_sql,
      #     conditions_key: config.conditions_key,
      #     conditions: cond,
      #     multiselect_key: config.multiselect_key,
      #     multiselect_opts: config.multiselect_opts,
      #     edit_rules: config.edit_rules,
      #     calculated_columns: config.calculated_columns,
      #     grid_caption: config.grid_caption,
      #     page_controls: config.page_control_defs
      #   }
      # end

      def in_params(input_parameters)
        in_keys = []
        eq_sel = input_parameters.select { |p| p['op'] == '=' }.group_by { |p| p['col'] }
        eq_sel.each do |col, qp|
          in_keys << col if qp.length > 1
        end
        in_keys
      end

      def params_to_parms(params) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        input_parameters = ::JSON.parse(params[:json_var]) || []
        parms = initialise_params
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
                  [in_param['val'], in_param['valTo']]
                else
                  in_param['val']
                end
          next if val.to_s.empty? && in_param['optional'] # Optional parameter ignored for nil value...

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
        rescue PgQuery::ParseError => e
          puts e.message
          puts e.backtrace.join("\n")
          raise Roda::RodaPlugins::DataGrid::Error, "Dataminer grid SQL error: #{e.message}"
        end
      end

      def conditions
        return nil if config.conditions.empty?

        config.conditions.map do |condition|
          if condition[:val].to_s.include?('$')
            parameterize_value(condition.dup)
          else
            condition
          end
        end
      end

      def excel_rows # rubocop:disable Metrics/AbcSize
        apply_params(params)

        xls_possible_types = { string: :string, integer: :integer, date: :string,
                               datetime: :time, time: :time, boolean: :boolean, number: :float }
        heads     = []
        fields    = []
        xls_types = []
        x_styles  = []
        res       = nil
        Axlsx::Package.new do |p|
          p.workbook do |wb|
            styles     = wb.styles
            tbl_header = styles.add_style b: true, font_name: 'arial', alignment: { horizontal: :center }
            # red_negative = styles.add_style num_fmt: 8
            delim4 = styles.add_style(format_code: '#,##0.0000;[Red]-#,##0.0000')
            delim2 = styles.add_style(format_code: '#,##0.00;[Red]-#,##0.00')
            and_styles = { delimited_1000_4: delim4, delimited_1000: delim2 } # rubocop:disable Naming/VariableNumber
            report.ordered_columns.each do |col|
              xls_types << xls_possible_types[col.data_type] || :string # BOOLEAN == 0,1 ... need to change this to Y/N...or use format TRUE|FALSE...
              heads << col.caption
              fields << col.name
              # x_styles << (col.format == :delimited_1000_4 ? delim4 : :delimited_1000 ? delim2 : nil)
              # # num_fmt: Axlsx::NUM_FMT_YYYYMMDDHHMMSS / Axlsx::NUM_FMT_PERCENT
              x_styles << and_styles[col.format]
            end
            puts x_styles.inspect
            wb.add_worksheet do |sheet|
              sheet.add_row heads, style: tbl_header
              # Crossbeams::DataminerInterface::DB[@rpt.runnable_sql].each do |row|
              DB[report.runnable_sql].each do |row|
                sheet.add_row(fields.map do |f|
                  v = row[f.to_sym]
                  v.is_a?(BigDecimal) ? v.to_f : v
                end, types: xls_types, style: x_styles)
              end
            end
          end
          # response.headers['content_type'] = "application/vnd.ms-excel"
          # response.headers['Content-Disposition'] = "attachment; filename=\"#{ @rpt.caption.strip.gsub(/[\/:*?"\\<>\|\r\n]/i, '-') + '.xls' }\""
          # response.write(p.to_stream.read) # NOTE: could this use streaming to start downloading quicker?
          res = p.to_stream.read
        end
        res
      end

      private

      # If the search config definition has fixed parameters, return them, otherwise return an empty array.
      def initialise_params
        return [] unless config.fixed_parameters

        config.fixed_parameters.map do |fp|
          col = fp[:col]
          raise Roda::RodaPlugins::DataGrid::Error, "#{col} is a fixed parameter. It cannot also be a selected parameter" if config.selected_parameter_list.include?(col)

          param_def = report.parameter_definition(col)
          raise Roda::RodaPlugins::DataGrid::Error, "There is no parameter for this grid query named \"#{col}\"" if param_def.nil?

          Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(fp[:op], fp[:val], param_def.data_type))
        end
      end

      # The hide_ and show_ env var settings contain a list of env vars and values:
      # hide_if_env_var: 'X_ONLY:y,Y_COLOUR:blue'. (ENV['X_ONLY'] == 'y'; ENV'COLOUR'] == 'blue')
      # If an env var exists and its value matches, the action will be hiden/shown.
      # A special variable value '<present>' triggers the show/hide if the env var
      # has ANY value. ('CHECK_THIS:<present>')
      def env_var_prevents_action?(hide_if_env_var, show_if_env_var)
        return false if hide_if_env_var.nil? && show_if_env_var.nil?

        hide_action = false
        hide_action = check_hide_action(hide_if_env_var) if hide_if_env_var
        return true if hide_action

        hide_action = check_show_action(show_if_env_var) if show_if_env_var
        hide_action
      end

      def check_hide_action(hide_if_env_var)
        hides = hide_if_env_var.split(',').map { |h| h.split(':') }
        hide = false
        hides.each do |key, val|
          next unless ENV[key]

          hide = true if val == '<present>'
          hide = true if ENV[key] == val
        end
        hide
      end

      def check_show_action(show_if_env_var)
        shows = show_if_env_var.split(',').map { |h| h.split(':') }
        show = false
        shows.each do |key, val|
          next unless ENV[key]

          show = true if val == '<present>'
          show = true if ENV[key] == val
        end
        !show
      end

      def client_rule_prevents_action?(hide_condition, show_condition)
        return false unless hide_condition || show_condition
        return false unless @client_rule_check

        checker = ClientRuleCheck.new(@client_rule_check)
        return true if checker.should_hide?(hide_condition)
        return true unless checker.should_show?(show_condition)

        false
      end

      def parse_params(options)
        return nil unless options[:params]

        qstr = options[:params].delete(:query_string)
        return options[:params] if qstr.nil?

        options[:params].merge(Rack::Utils.parse_nested_query(qstr))
      end

      def parameterize_value(condition)
        val = condition[:val]
        @params.each { |k, v| val.gsub!("$:#{k}$", v.nil? ? '' : v) }
        val = translate_special_variables(val)
        condition[:val] = val
        condition[:val] = condition_value_as_array(val) if condition[:op].match?(/in/i)
        condition
      end

      SPECIAL_VARIABLES = {
        '$:START_OF_DAY$' => -> { Date.today.strftime('%Y-%m-%d 00:00:00') },
        '$:END_OF_DAY$' => -> { Date.today.strftime('%Y-%m-%d 23:59:59') },
        '$:TODAY$' => -> { Date.today.strftime('%Y-%m-%d') }
      }.freeze

      def translate_special_variables(val)
        if SPECIAL_VARIABLES[val]
          SPECIAL_VARIABLES[val].call
        else
          val
        end
      end

      def condition_value_as_array(val)
        return val if val.is_a?(Array)
        return Array(val) unless val.is_a?(String)

        val.sub('[', '').sub(']', '').split(',').map(&:strip)
      end

      # For multiselect grids, get the ids that should be preselected in the grid.
      #
      # @return [Array] - a list of ids (can be empty)
      def preselect_ids # rubocop:disable Metrics/AbcSize
        return [] if config.multiselect_opts[:preselect].nil? || params.nil?

        sql = config.multiselect_opts[:preselect]
        params.each { |k, v| sql.gsub!("$:#{k}$", v.to_s) }
        assert_sql_is_select!('preselect', sql)
        DB[sql].map { |r| r.values.first }
      end

      def dataminer_query(sql) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
        hstore = Object.const_defined?('Sequel::Postgres::HStore')
        DB[sql].to_a.map do |rec|
          rec.each_key do |key|
            rec[key] = rec[key].map { |a, b| [a, b.to_f] } if @multi_dimensional_arrays.include?(key)
            rec[key] = rec[key].to_f if rec[key].is_a?(BigDecimal)
            rec[key] = rec[key].to_s if hstore && rec[key].is_a?(Sequel::Postgres::HStore)
            rec[key] = row_style(rec[key]) if key == :colour_rule
          end
          rec
        end
      end

      def row_style(klass)
        Crossbeams::Layout::StylesConfig.config.grid_row_colours[klass] || klass
      end

      def limit_from_params(params)
        return @params[:_limit].to_i if @params && @params[:_limit]

        params[:limit].to_i  unless params[:limit].nil? || params[:limit] == ''
      end

      def offset_from_params(params)
        return @params[:_offset].to_i if @params && @params[:_offset]

        params[:offset].to_i unless params[:offset].nil? || params[:offset] == ''
      end

      def assert_sql_is_select!(context, sql)
        raise ArgumentError, "SQL for \"#{context}\" is not a SELECT" if sql.match?(/insert |update |delete /i)
      end

      def multiselect_ids
        config.multiselect ? preselect_ids : []
      end

      def select_editor_values(rule) # rubocop:disable Metrics/AbcSize
        return rule[:values] if rule[:values]

        sql = rule[:value_sql]
        raise ArgumentError, 'A select cell editor must have a :values array or a :value_sql string' if sql.nil?

        params&.each { |k, v| sql.gsub!("$:#{k}$", v.to_s) }
        assert_sql_is_select!('select editor', sql)
        DB[sql].map { |r| r.values.length > 1 ? r.values : r.values.first }
      end
    end
  end
end
