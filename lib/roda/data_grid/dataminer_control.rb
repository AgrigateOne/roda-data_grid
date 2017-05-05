class DataminerControl
  attr_reader :report, :search_def, :list_def

  # TODO: Use some kind of config for this
  # ROOT = File.join(File.dirname(__FILE__), '..')

  # Could we store dataminer behaviours in another yml file?
  # - rules for colours
  # - rules for links
  # - etc

  def initialize(options)
    @root = options[:path]

    if options[:search_file]
      @search_def = load_search_definition(options[:search_file])
      @report     = get_report(@search_def[:dataminer_definition])
    elsif options[:list_file]
      @list_def   = load_list_definition(options[:list_file])
      @report     = get_report(@list_def[:dataminer_definition])
    else
      @report     = get_report(options[:report_file])
    end
  end

  def search_rows(params)
    apply_params(params)

    actions  = search_def[:actions]
    col_defs = column_definitions(report, actions: actions)

    {
      columnDefs: col_defs,
      rowDefs:    dataminer_query(report.runnable_sql)
    }.to_json
  end

  def list_rows
    n_params = { json_var: list_def[:conditions].to_json }
    apply_params(n_params) unless n_params.nil? || n_params.empty?

    actions  = list_def[:actions]
    col_defs = column_definitions(report, actions: actions)

    {
      columnDefs: col_defs,
      rowDefs:    dataminer_query(report.runnable_sql)
    }.to_json
  end

  def apply_params(params)
    # {"col"=>"users.department_id", "op"=>"=", "opText"=>"is", "val"=>"17", "text"=>"Finance", "caption"=>"Department"}
    input_parameters = ::JSON.parse(params[:json_var]) || []
    parms = []
    # Check if this should become an IN parmeter (list of equal checks for a column.
    eq_sel = input_parameters.select { |p| p['op'] == '=' }.group_by { |p| p['col'] }
    in_sets = {}
    in_keys = []
    eq_sel.each do |col, qp|
      in_keys << col if qp.length > 1
    end

    input_parameters.each do |in_param|
      col = in_param['col']
      if in_keys.include?(col)
        in_sets[col] ||= []
        in_sets[col] << in_param['val']
        next
      end
      param_def = report.parameter_definition(col)
      if 'between' == in_param['op']
        parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], [in_param['val'], in_param['val_to']], param_def.data_type))
      else
        parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], in_param['val'], param_def.data_type))
      end
    end
    in_sets.each do |col, vals|
      param_def = report.parameter_definition(col)
      parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new('in', vals, param_def.data_type))
    end

    report.limit  = params[:limit].to_i  if params[:limit] != ''
    report.offset = params[:offset].to_i if params[:offset] != ''
    begin
      report.apply_params(parms)
    rescue StandardError => e
      return "ERROR: #{e.message}"
    end
  end

  private

  def dataminer_query(sql)
    # Need to convert all BigDecimal to float for JSON (otherwise the aggregations don't work because amounts are returned as 0.1126673E5)
    # - Need to do some checking that the resulting float is an accurate representation of the decimal...
    DB.base[sql].to_a.map do |rec|
      rec.keys.each do |key|
        rec[key] = rec[key].to_f if rec[key].is_a?(BigDecimal)
      end
      rec
    end
  end

  def load_search_definition(file_name)
    path = File.join(@root, 'grid_definitions', 'searches', file_name.sub('.yml', '') << '.yml')
    YAML.load(File.read(path))
  end

  def load_list_definition(file_name)
    path = File.join(@root, 'grid_definitions', 'lists', file_name.sub('.yml', '') << '.yml')
    YAML.load(File.read(path))
  end

  # Load a YML report.
  def get_report(file_name) # TODO:  'bookshelf' should be variable...
    path     = File.join(@root, 'grid_definitions', 'dataminer_queries', file_name.sub('.yml', '') << '.yml')
    rpt_hash = Crossbeams::Dataminer::YamlPersistor.new(path)
    Crossbeams::Dataminer::Report.load(rpt_hash)
  end

  def column_definitions(report, options = {})
    col_defs = []

    # Actions
    # TODO:
    #       1. Combine into action collection column.
    #       2. Bring user permissions in to play.
    if options[:actions]
      options[:actions].each_with_index do |action, index|
        renderer = action[:is_delete] ? 'crossbeamsGridFormatters.hrefPromptFormatter' : 'crossbeamsGridFormatters.hrefSimpleFormatter'
        suffix   = "|#{action[:text] || 'link'}"
        suffix << '|Are you sure?' if action[:is_delete]
        link = "'#{action[:url].gsub('{:id}', "'+data.id+'")}#{suffix}'"

        hs = { headerName: '',
               width: action[:width] || 60,
               suppressMenu: true,   suppressSorting: true,   suppressMovable: true,
               suppressFilter: true, enableRowGroup: false,   enablePivot: false,
               enableValue: false,   suppressCsvExport: true, suppressToolPanel: true,
               valueGetter: link,
               colId: "link_#{index}",
               cellRenderer: renderer }
        col_defs << hs
      end
    end

    report.ordered_columns.each do |col|
      hs                  = { headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption }
      hs[:width]          = col.width unless col.width.nil?
      hs[:enableValue]    = true if %i[integer number].include?(col.data_type)
      hs[:enableRowGroup] = true unless hs[:enableValue] && !col.groupable
      hs[:enablePivot]    = true unless hs[:enableValue] && !col.groupable
      if %i[integer number].include?(col.data_type)
        hs[:cellClass] = 'grid-number-column'
        hs[:width]     = 100 if col.width.nil? && col.data_type == :integer
        hs[:width]     = 120 if col.width.nil? && col.data_type == :number
      end
      if col.format == :delimited_1000
        hs[:cellRenderer] = 'crossbeamsGridFormatters.numberWithCommas2'
      end
      if col.format == :delimited_1000_4
        hs[:cellRenderer] = 'crossbeamsGridFormatters.numberWithCommas4'
      end
      if col.data_type == :boolean
        hs[:cellRenderer] = 'crossbeamsGridFormatters.booleanFormatter'
        hs[:cellClass]    = 'grid-boolean-column'
        hs[:width]        = 100 if col.width.nil?
      end

      # hs[:cellClassRules] = {"grid-row-red": "x === 'Fred'"} if col.name == 'author'

      col_defs << hs
    end
    col_defs
  end
end
