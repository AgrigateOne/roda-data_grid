# frozen_string_literal: true

module Crossbeams
  module DataGrid
    class ListGridData

      # Column and row definitions for a list grid.
      #
      # @return [JSON] - a Hash containing row and column definitions.
      def list_rows
        multiselect = @multiselect_options.nil? ? nil : list_def[:multiselect]
        if multiselect && @multiselect_options[:key]
          @grid_params ||= {}
          if multiselect[@multiselect_options[:key].to_sym][:conditions]
            conditions = Array(list_def[:conditions][multiselect[@multiselect_options[:key].to_sym][:conditions].to_sym]).map do |condition|
              if condition[:val].to_s.include?('$')
                parameterize_value(condition)
              else
                condition
              end
            end
          else
            conditions = nil
          end
        else
          conditions = list_def[:conditions].nil? || @grid_params.nil? || @grid_params.empty? ? nil : conditions_from(list_def)
        end
        n_params = { json_var: conditions.to_json }
        apply_params(n_params) unless n_params.nil? || n_params.empty?

        actions     = list_def[:actions]
        col_defs    = column_definitions(report, actions: actions, multiselect: multiselect)
        multiselect_ids = list_def[:multiselect].nil? || @multiselect_options.nil? ? [] : preselect_ids(list_def[:multiselect][@multiselect_options[:key].to_sym])

        {
          multiselect_ids: multiselect_ids,
          tree: list_def[:tree],
          columnDefs: col_defs,
          rowDefs:    dataminer_query(report.runnable_sql)
        }.to_json
      end

      def list_nested_rows
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
    end
  end
end
__END__

ListConfig
init(options)
        @id = options.fetch(:id)
        @root = options.fetch(:root_path)
        @multiselect_key = options[:multi_key]&.to_sym
        @params = options[:params]
        >>>> @fit_height = @params&.delete(:fit_height)
        >>>> @grid_opts = options[:grid_opts] || default_grid_opts
        >>>> @grid_caption = options[:grid_caption]
        @config_loader = options[:config_loader] || -> { load_config_from_file }
        load_config

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
        >>>> @grid_caption = @multiselect_opts[:grid_caption] if @multiselect_opts[:grid_caption] && @grid_caption.nil?
        >>>> @grid_caption = config[:grid_caption] if @grid_caption.nil?
        # condition_sets = config[:conditions] || {}
        # @conditions = if @multiselect_key && @multiselect_opts[:conditions]
        #                 condition_sets[@multiselect_opts[:conditions]]
        #               elsif @conditions_key
        #                 condition_sets[@conditions_key]
        #               else
        #                 []
        #               end
      end


def init(id, root_path, grid_opts, deny_access, params, multi_key) #==> this might read ListGridDef? (OR both could read ListGridConfig????)
def init(list, options)
def init(:list, root_path: opt_path, grid_opts: opts[:data_grid], id: id, deny_access: deny_access, params: params, multi_key: multi_key) #==> this might read ListGridDef?
def list_rows

          grid_def = Crossbeams::DataGrid::ListGridDefinition.new(root_path: opt_path,
                                                                  grid_opts: opts[:data_grid],
                                                                  id: id,
                                                                  params: params)
          grid_def = Crossbeams::DataGrid::ListGridDefinition.new(root_path: opt_path,
                                                                  grid_opts: opts[:data_grid],
                                                     #==>         multi_key: params[:key],
                                                                  id: id,
                                                                  params: params)
        def render_data_grid_rows(id, deny_access = nil, params = nil)
          dmc = if params.nil?
                  DataminerControl.new(path: opt_path, list_file: id, deny_access: deny_access)
                else
                  DataminerControl.new(path: opt_path, list_file: id, deny_access: deny_access, grid_params: params)
                end
          dmc.list_rows
        end

        def render_data_grid_multiselect_rows(id, deny_access, multi_key, params)
          mult = multi_key.nil? ? nil : { key: multi_key, params: params }
          dmc = DataminerControl.new(path: opt_path, list_file: id, deny_access: deny_access, multiselect_options: mult)
          dmc.list_rows
        end

        def render_data_grid_nested_rows(id)
          dmc = DataminerControl.new(path: opt_path, list_file: id)
          dmc.list_nested_rows
        end
