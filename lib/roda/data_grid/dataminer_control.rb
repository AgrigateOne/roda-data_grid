# frozen_string_literal: true

class DataminerControl
  attr_reader :report, :search_def, :list_def

  # TODO: Use some kind of config for this
  # ROOT = File.join(File.dirname(__FILE__), '..')

  # Could we store dataminer behaviours in another yml file?
  # - rules for colours
  # - rules for links
  # - etc

  def initialize(options) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    @root = options[:path]
    @deny_access = options[:deny_access] || ->(_, _, _) { false }
    @client_rule_check = options[:client_rule_check]

    @multiselect_options = options[:multiselect_options]
    @grid_params = options[:grid_params] || @multiselect_options && @multiselect_options[:params].dup
    @hide_for_client = []
    if options[:search_file]
      @search_def = load_search_definition(options[:search_file])
      @report = get_report(dataminer_def(@search_def))
      @hide_for_client = @search_def.dig(:hide_for_client, ENV['CLIENT_CODE']) || []
    elsif options[:list_file]
      @list_def = load_list_definition(options[:list_file])
      @report = get_report(dataminer_def(@list_def))
    else
      @report = get_report(options[:report_file])
    end
  end

  # Does this search or list grid need to be rendered as a nested grid.
  #
  # @return [boolean] - true if nested, otherwise false.
  def is_nested_grid? # rubocop:disable Naming/PredicateName
    search_def && search_def[:nesting] || list_def && list_def[:nesting]
  end

  # Does this search or list grid need to be rendered as a multiselect grid.
  #
  # @return [boolean] - true if multiselect, otherwise false.
  def is_multiselect? # rubocop:disable Naming/PredicateName
    !@multiselect_options.nil?
  end

  # Parameters to use if this search or list grid needs to be rendered as a tree grid.
  #
  # @return [nil, Hash] - Config for tree.
  def tree_def
    search_def && search_def[:tree] || list_def && list_def[:tree]
  end

  # Search: get the colour_key from the report definition
  #
  # @return [nil, Hash] - the colour key
  def colour_key
    @report.external_settings[:colour_key]
  end

  # Run the given SQL to see if a page control should be hidden.
  #
  # @return [boolean] - Hide or do not hide the control.
  def hide_control_by_sql(page_control_def)
    sql = page_control_def[:hide_if_sql_returns_true]
    check_sql_is_safe('hide_if_sql_returns_true', sql)
    DB[sql].get
  end

  # The URL that a multiselect grid's selection should be saved to.
  #
  # @return [String] - the URL.
  def multiselect_url
    # test on list_def for now...
    details = @list_def[:multiselect][@multiselect_options[:key].to_sym]
    raise ArgumentError, 'incorrect arguments for multiselect parameters' if details.nil?

    details[:url].sub('$:id$', @multiselect_options[:id])
  end

  def multi_grid_caption
    return nil unless @multiselect_options

    caption = @list_def[:multiselect][@multiselect_options[:key].to_sym][:section_caption]
    return nil if caption.nil?

    return caption unless caption.match?(/SELECT/i)

    sql = caption.sub('$:id$', @multiselect_options[:id])
    check_sql_is_safe('caption', sql)
    DB[sql].first.values.first
  end

  def multiselect_can_be_cleared
    return nil unless @multiselect_options

    @list_def[:multiselect][@multiselect_options[:key].to_sym][:can_be_cleared]
  end

  def multiselect_save_method
    return nil unless @multiselect_options

    @list_def[:multiselect][@multiselect_options[:key].to_sym][:multiselect_save_method]
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
  def search_rows(params) # rubocop:disable Metrics/AbcSize
    apply_params(params)

    actions     = search_def[:actions]
    multiselect = @multiselect_options.nil? ? nil : search_def[:multiselect]
    col_defs    = column_definitions(report, actions: actions, multiselect: multiselect)
    multiselect_ids = search_def[:multiselect].nil? || @multiselect_options.nil? ? [] : preselect_ids(search_def[:multiselect][@multiselect_options[:key].to_sym])

    {
      multiselect_ids: multiselect_ids,
      columnDefs: col_defs,
      rowDefs: dataminer_query(report.runnable_sql)
    }.to_json
  end

  # Column and row definitions for a list grid.
  #
  # @return [JSON] - a Hash containing row and column definitions.
  def list_rows # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    multiselect = @multiselect_options.nil? ? nil : list_def[:multiselect]
    if multiselect && @multiselect_options[:key]
      @grid_params ||= {}
      conditions = if multiselect[@multiselect_options[:key].to_sym][:conditions]
                     Array(list_def[:conditions][multiselect[@multiselect_options[:key].to_sym][:conditions].to_sym]).map do |condition|
                       if condition[:val].to_s.include?('$')
                         parameterize_value(condition)
                       else
                         condition
                       end
                     end
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
      rowDefs: dataminer_query(report.runnable_sql)
    }.to_json
  end

  # Column and row definitions for a nested list grid.
  #
  # @return [JSON] - a Hash containing row and column definitions.
  def list_nested_rows # rubocop:disable Metrics/AbcSize
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
      rowDefs: dataminer_nested_query(report.runnable_sql)
    }.to_json
  end

  def excel_rows(params) # rubocop:disable Metrics/AbcSize
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

  def apply_params(params) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
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
  def dataminer_nested_query(sql) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
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
  rescue Psych::SyntaxError => e
    raise Error, "Syntax error in YAML file (#{file_name.sub('.yml', '') << '.yml'}). The syntax error is: #{e.message}"
  end

  def load_list_definition(file_name)
    path = File.join(@root, 'grid_definitions', 'lists', file_name.sub('.yml', '') << '.yml')
    YAML.load(File.read(path))
  rescue Psych::SyntaxError => e
    raise Error, "Syntax error in YAML file (#{file_name.sub('.yml', '') << '.yml'}). The syntax error is: #{e.message}"
  end

  # Load a YML report.
  def get_report(file_name)
    path     = File.join(@root, 'grid_definitions', 'dataminer_queries', file_name.sub('.yml', '') << '.yml')
    rpt_hash = Crossbeams::Dataminer::YamlPersistor.new(path)
    Crossbeams::Dataminer::Report.load(rpt_hash)
  end

  # Build action column items recursively.
  def make_subitems(actions, level = 0) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    this_col = []
    cnt = 0
    actions.each do |action|
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
      next if env_var_prevents_action?(action[:hide_if_env_var], action[:show_if_env_var])
      next if client_rule_prevents_action?(action[:hide_for_client_rule], action[:show_for_client_rule])

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

    checker = Crossbeams::DataGrid::ClientRuleCheck.new(@client_rule_check)
    return true if checker.should_hide?(hide_condition)
    return true unless checker.should_show?(show_condition)

    false
  end

  def column_definitions(report, options = {}) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
    col_defs = []

    # TEST: multiselect
    if options[:multiselect]
      hs = {
        headerName: '',
        colId: 'theSelector',
        pinned: 'left',
        width: 45,
        headerCheckboxSelection: true,
        headerCheckboxSelectionFilteredOnly: true,
        checkboxSelection: true,
        suppressMenu: true,   sortable: false,   suppressMovable: true,
        filter: false, enableRowGroup: false,   enablePivot: false,
        enableValue: false,   suppressCsvExport: true, suppressColumnsToolPanel: true,
        suppressFiltersToolPanel: true
      }
      col_defs << hs
    end

    # Actions
    # TODO:
    #       x. Combine into action collection column.
    #       2. Bring user permissions in to play.
    if options[:actions]
      this_col = make_subitems(options[:actions])
      hs = { headerName: '', pinned: 'left',
             width: 60,
             suppressMenu: true,   sortable: false,   suppressMovable: true,
             filter: false, enableRowGroup: false,   enablePivot: false,
             enableValue: false,   suppressCsvExport: true, suppressColumnsToolPanel: true,
             suppressFiltersToolPanel: true,
             valueGetter: this_col.to_json.to_s,
             colId: 'action_links',
             cellRenderer: 'crossbeamsGridFormatters.menuActionsRenderer' }
      col_defs << hs
    end

    (options[:column_set] || report.ordered_columns).each do |col|
      hs                  = { headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption }
      hs[:hide]           = true if @hide_for_client.include?(col.name)
      hs[:width]          = col.width unless col.width.nil?
      hs[:width]          = Crossbeams::DataGrid::COLWIDTH_DATETIME if col.width.nil? && col.data_type == :datetime
      hs[:enableValue]    = true if %i[integer number].include?(col.data_type)
      hs[:enableRowGroup] = true unless tree_def || hs[:enableValue] && !col.groupable
      hs[:enablePivot]    = true unless tree_def || hs[:enableValue] && !col.groupable
      hs[:rowGroupIndex]  = col.group_by_seq if col.group_by_seq
      # hs[:pinned]         = 'left' if col.group_by_seq # if col.pinned || col.group_by_seq
      hs[:rowGroup]       = true if col.group_by_seq
      # hs[:valueGetter]    = 'blankWhenNull'

      if %i[integer number].include?(col.data_type)
        hs[:cellClass] = 'grid-number-column'
        hs[:width]     = Crossbeams::DataGrid::COLWIDTH_INTEGER if col.width.nil? && col.data_type == :integer
        hs[:width]     = Crossbeams::DataGrid::COLWIDTH_NUMBER if col.width.nil? && col.data_type == :number
      end

      hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas2' if col.format == :delimited_1000
      hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas4' if col.format == :delimited_1000_4

      if col.data_type == :boolean
        hs[:cellRenderer] = 'crossbeamsGridFormatters.booleanFormatter'
        hs[:cellClass]    = 'grid-boolean-column'
        hs[:width]        = Crossbeams::DataGrid::COLWIDTH_BOOLEAN if col.width.nil?
      end
      hs[:valueFormatter] = 'crossbeamsGridFormatters.dateTimeWithoutSecsOrZoneFormatter' if col.data_type == :datetime
      hs[:valueFormatter] = 'crossbeamsGridFormatters.dateTimeWithoutZoneFormatter' if col.format == :datetime_with_secs

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

  # For multiselect grids, get the ids that should be preselected in the grid.
  #
  # @return [Array] - a list of ids (can be empty)
  def preselect_ids(options)
    return [] if options.nil? || options[:preselect].nil?

    sql = options[:preselect]
    @multiselect_options[:params].each { |k, v| sql.gsub!("$:#{k}$", v) }
    check_sql_is_safe('preselect', sql)
    DB[sql].map { |r| r.values.first }
  end

  def parameterize_value(condition)
    val = condition[:val]
    @grid_params.each { |k, v| val.gsub!("$:#{k}$", v) }
    condition[:val] = val
    condition[:val] = condition_value_as_array(val) if condition[:op].match?(/in/i)
    condition
  end

  def condition_value_as_array(val)
    return val if val.is_a?(Array)
    return Array(val) unless val.is_a?(String)

    val.sub('[', '').sub(']', '').split(',').map(&:strip)
  end

  def conditions_from(list_or_search_def)
    return nil unless @grid_params[:key]
    return nil unless list_or_search_def[:conditions][@grid_params[:key].to_sym]

    conditions = list_or_search_def[:conditions][@grid_params[:key].to_sym]
    conditions.map! do |condition|
      if condition[:val].to_s.include?('$')
        parameterize_value(condition)
      else
        condition
      end
    end
    conditions
  end

  def check_sql_is_safe(context, sql)
    raise ArgumentError, "SQL for \"#{context}\" is not a SELECT" if sql.match?(/insert |update |delete /i)
  end

  def dataminer_def(config)
    dataminer_definition = config[:dataminer_definition]
    return dataminer_definition unless ENV['CLIENT_CODE']

    defn = config.dig(:dataminer_client_definitions, ENV['CLIENT_CODE'])
    defn.nil? ? dataminer_definition : defn
  end
end
