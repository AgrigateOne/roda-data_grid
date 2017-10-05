# frozen_string_literal: true

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
    @deny_access = options[:deny_access] || lambda { |programs, permission| false }

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

  # Does this search or list grid need to be rendered as a nested grid.
  #
  # @return [boolean] - true if nested, otherwise false.
  def is_nested_grid?
    search_def && search_def[:nesting] || list_def && list_def[:nesting]
  end

  # Get the rules for which (if any) controls to display on the page.
  #
  # @return [Array] - the control definitions. Could be empty.
  def page_controls
    pc = search_def[:page_controls] if search_def
    pc = list_def[:page_controls] if list_def
    pc || []
  end

  # Column and row definitions for a search grid.
  #
  # @return [JSON] - a Hash containing row and column definitions.
  def search_rows(params)
    apply_params(params)

    actions  = search_def[:actions]
    col_defs = column_definitions(report, actions: actions)

    {
      columnDefs: col_defs,
      rowDefs:    dataminer_query(report.runnable_sql)
    }.to_json
  end

  # Column and row definitions for a list grid.
  #
  # @return [JSON] - a Hash containing row and column definitions.
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

  # Column and row definitions for a nested list grid.
  #
  # @return [JSON] - a Hash containing row and column definitions.
  def list_nested_rows
    n_params = { json_var: list_def[:conditions].to_json }
    apply_params(n_params) unless n_params.nil? || n_params.empty?

    nested_defs = {}
    list_def[:nesting][:columns].each do |level, cols|
      actions = list_def[:nesting][:actions][level]
      column_set = cols.map { |c| report.column(c.to_s) }
      level_expander = list_def[:nesting][:expand_columns][level].to_s
      col_defs = column_definitions(report, actions: actions, column_set: column_set, expands_nested_grid: level_expander)
      nested_defs[level] = col_defs
    end

    {
      nestedColumnDefs: nested_defs,
      rowDefs:    dataminer_nested_query(report.runnable_sql)
    }.to_json
  end

  def excel_rows(params)
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
        and_styles = { delimited_1000_4: delim4, delimited_1000: delim2 }
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

  def apply_params(params)
    # { "col"=>"users.department_id", "op"=>"=", "opText"=>"is", "val"=>"17", "text"=>"Finance", "caption"=>"Department" }
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
      parms << if in_param['op'] == 'between'
                 Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], [in_param['val'], in_param['val_to']], param_def.data_type))
               else
                 Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], in_param['val'], param_def.data_type))
               end
      # if 'between' == in_param['op']
      #   parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], [in_param['val'], in_param['val_to']], param_def.data_type))
      # else
      #   parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new(in_param['op'], in_param['val'], param_def.data_type))
      # end
    end
    in_sets.each do |col, vals|
      param_def = report.parameter_definition(col)
      parms << Crossbeams::Dataminer::QueryParameter.new(col, Crossbeams::Dataminer::OperatorValue.new('in', vals, param_def.data_type))
    end
    report.limit  = params[:limit].to_i  unless params[:limit].nil? || params[:limit] != ''
    report.offset = params[:offset].to_i unless params[:offset].nil? || params[:offset] != ''
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
    DB[sql].to_a.map do |rec|
      rec.keys.each do |key|
        rec[key] = rec[key].to_f if rec[key].is_a?(BigDecimal)
      end
      rec
    end
  end

  # TODO: Hard-coded to 3 levels. Needs to be dynamic...
  def dataminer_nested_query(sql)
    column_levels = {}
    detail_level = 0
    prev_keys = {}
    level_hash = {}
    key_columns = list_def[:nesting][:keys]
    list_def[:nesting][:columns].each do |k, v|
      detail_level += 1
      prev_keys[k] = -1
      v.each { |col| column_levels[col] = k }
      level_hash[k] = {}
    end
    new_set = []
    new_rec = {}
    # FIXME: chunks of func 1 program in func2 - which has no programs......
    DB[sql].to_a.each do |rec|
      # puts ">>> #{rec[key_columns[1]]}"
      if rec[key_columns[1]] != prev_keys[1]
        new_set << new_rec unless new_rec.empty?
        new_rec = {}
        list_def[:nesting][:columns][1].each do |col|
          new_rec[col] = rec[col].is_a?(BigDecimal) ? rec[col].to_f : rec[col]
        end
        new_rec[:level2] = []
        prev_keys[1] = rec[key_columns[1]]
      end
      if rec[key_columns[2]] != prev_keys[2] # might be nil...
        new_rec[:level2] << level_hash[2] unless level_hash[2].empty?
        unless rec[key_columns[2]].nil?
          level_hash[2] = {}
          list_def[:nesting][:columns][2].each do |col|
            level_hash[2][col] = rec[col].is_a?(BigDecimal) ? rec[col].to_f : rec[col]
          end
          level_hash[2][:level3] = []
        end
        prev_keys[2] = rec[key_columns[2]]
      end

      level_hash[3] = {}
      next if rec[key_columns[3]].nil?

      list_def[:nesting][:columns][3].each do |col|
        level_hash[3][col] = rec[col].is_a?(BigDecimal) ? rec[col].to_f : rec[col]
      end
      level_hash[2][:level3] << level_hash[3]
    end
    new_rec[:level2] << level_hash[2] unless level_hash[2].empty?
    new_set << new_rec unless new_rec.empty?
    new_set
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

  # Build action column items recursively.
  def make_subitems(actions, level = 0)
    this_col = []
    cnt = 0
    actions.each do |action|
      if action[:separator]
        cnt += 1
        this_col << { text: "sep#{level}#{cnt}", is_separator: true }
        next
      end
      if action[:submenu]
        this_col << { text: action[:submenu][:text], is_submenu: true, items: make_subitems(action[:submenu][:items], level+1) }
        next
      end

      # Check if user is authorised for this action:
      next if action[:auth] && @deny_access.call(action[:auth][:program], action[:auth][:permission])

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
      this_col << link_h
    end
    this_col
  end

  def column_definitions(report, options = {})
    col_defs = []

    # Actions
    # TODO:
    #       x. Combine into action collection column.
    #       2. Bring user permissions in to play.
    if options[:actions]
      this_col = make_subitems(options[:actions])
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

    (options[:column_set] || report.ordered_columns).each do |col|
      hs                  = { headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption }
      hs[:width]          = col.width unless col.width.nil?
      hs[:enableValue]    = true if %i[integer number].include?(col.data_type)
      hs[:enableRowGroup] = true unless hs[:enableValue] && !col.groupable
      hs[:enablePivot]    = true unless hs[:enableValue] && !col.groupable
      hs[:rowGroupIndex]  = col.group_by_seq if col.group_by_seq
      # hs[:pinned]         = 'left' if col.group_by_seq # if col.pinned || col.group_by_seq
      hs[:rowGroup]       = true if col.group_by_seq
      hs[:valueGetter]    = 'blankWhenNull'

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
end
