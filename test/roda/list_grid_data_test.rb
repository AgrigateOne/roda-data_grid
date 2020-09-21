require 'test_helper'
require 'bigdecimal'

BASIC_DATA = [
  { 'id': 1, 'user_name': 'Fred', 'department_name': 'IT', 'created_at': Time.new(2018,9,01,13,40), 'amount': BigDecimal('12.34'), 'active': true },
  { 'id': 2, 'user_name': 'John', 'department_name': 'Finance', 'created_at': Time.new(2018,9,02,15,24), 'amount': BigDecimal('94.0212121'), 'active': false }
]
BASIC_EXPECTED = [
  { 'id' => 1, 'user_name' => 'Fred', 'department_name' => 'IT', 'created_at' => Time.new(2018,9,01,13,40).to_s, 'amount' => 12.34, 'active' => true },
  { 'id' => 2, 'user_name' => 'John', 'department_name' => 'Finance', 'created_at' => Time.new(2018,9,02,15,24).to_s, 'amount' => 94.0212121, 'active' => false }
]

ALLOW_ACCESS = ->(function, program, permission) { false }
DENY_ACCESS = ->(function, program, permission) { true }

HAS_PERMISSION = ->(args) { true }
NO_PERMISSION = ->(args) { false }

BASIC_DM_REPORT = {:caption=>nil,
 :sql=>
  "SELECT users.id, users.user_name, departments.department_name, users.created_at, users.amount, users.active FROM users JOIN departments ON departments.id = users.department_id",
 :limit=>nil,
 :offset=>nil,
 :external_settings=>{},
 :columns=>
  {"id"=>
    {:name=>"id",
     :sequence_no=>1,
     :caption=>"Id",
     :namespaced_name=>"users.id",
     :data_type=>:integer,
     :width=>nil,
     :format=>nil,
     :hide=>false,
     :groupable=>false,
     :group_by_seq=>nil,
     :group_sum=>false,
     :group_avg=>false,
     :group_min=>false,
     :group_max=>false},
   "user_name"=>
    {:name=>"user_name",
     :sequence_no=>2,
     :caption=>"First name",
     :namespaced_name=>"users.user_name",
     :data_type=>:string,
     :width=>150,
     :format=>nil,
     :hide=>false,
     :pinned=>'left',
     :groupable=>false,
     :group_by_seq=>nil,
     :group_sum=>false,
     :group_avg=>false,
     :group_min=>false,
     :group_max=>false},
   "department_name"=>
    {:name=>"department_name",
     :sequence_no=>3,
     :caption=>"Department name",
     :namespaced_name=>"departments.department_name",
     :data_type=>:string,
     :width=>nil,
     :format=>nil,
     :hide=>false,
     :groupable=>false,
     :group_by_seq=>nil,
     :group_sum=>false,
     :group_avg=>false,
     :group_min=>false,
     :group_max=>false},
   "created_at"=>
    {:name=>"created_at",
     :sequence_no=>4,
     :caption=>"Created at",
     :namespaced_name=>"users.created_at",
     :data_type=>:datetime,
     :width=>nil,
     :format=>nil,
     :hide=>false,
     :groupable=>false,
     :group_by_seq=>nil,
     :group_sum=>false,
     :group_avg=>false,
     :group_min=>false,
     :group_max=>false},
   "amount"=>
    {:name=>"amount",
     :sequence_no=>5,
     :caption=>"Amount",
     :namespaced_name=>"users.amount",
     :data_type=>:number,
     :width=>nil,
     :format=>:delimited_1000,
     :hide=>false,
     :groupable=>false,
     :group_by_seq=>nil,
     :group_sum=>false,
     :group_avg=>false,
     :group_min=>false,
     :group_max=>false},
   "active"=>
    {:name=>"active",
     :sequence_no=>6,
     :caption=>"Active",
     :namespaced_name=>"users.active",
     :data_type=>:boolean,
     :width=>nil,
     :format=>nil,
     :hide=>false,
     :groupable=>false,
     :group_by_seq=>nil,
     :group_sum=>false,
     :group_avg=>false,
     :group_min=>false,
     :group_max=>false}},
 :query_parameter_definitions=>
  [{:column=>"users.department_id",
    :caption=>"Department",
    :data_type=>:integer,
    :control_type=>:list,
    :default_value=>nil,
    :ordered_list=>44,
    :ui_priority=>1,
    :list_def=>"SELECT department_name, id FROM departments ORDER BY department_name"},
   {:column=>"users.user_name",
    :caption=>"Login name",
    :data_type=>:string,
    :control_type=>:text,
    :default_value=>nil,
    :ordered_list=>nil,
    :ui_priority=>1,
    :list_def=>["Fred", "John"]},
   {:column=>"users.id",
    :caption=>"ID",
    :data_type=>:integer,
    :control_type=>:text,
    :default_value=>nil,
    :ordered_list=>nil,
    :ui_priority=>1,
    :list_def=>nil},
   {:column=>"users.active",
    :caption=>"Active",
    :data_type=>:boolean,
    :control_type=>:text,
    :default_value=>nil,
    :ordered_list=>nil,
    :ui_priority=>1,
    :list_def=>nil},
   {:column=>"users.created_at",
    :caption=>"Created",
    :data_type=>:datetime,
    :control_type=>:daterange,
    :default_value=>nil,
    :ordered_list=>nil,
    :ui_priority=>1,
    :list_def=>nil}]}

class ListGridDataTest < Minitest::Test
  YAML_FILES = {
    list: { file: { dataminer_definition: 'a_report' }
    }
  }
  def basic_loader
    -> { YAML_FILES[:list][:file] }
  end

  def loader_extended(additions)
    -> { YAML_FILES[:list][:file].merge(additions) }
  end

  def test_required_options
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new({}) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(root_path: '/a/b/c') }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid') }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', deny_access: ALLOW_ACCESS) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', has_permission: HAS_PERMISSION) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c') }
  end

  def test_params
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: basic_loader)
    assert_nil data.params

    params = { one: 1 }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: basic_loader, params: params)
    assert_equal({ one: 1 }, data.params)

    params = { key: 'standard', sub_type_id: '3', product_column_ids: '[73, 74]' }
    additions = { conditions: { standard: [{ col: 'id', op: '=', val: '$:sub_type_id$' }] } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions), params: params)
    assert_equal '3', data.params[:sub_type_id]

    params = { query_string: 'key=standard&sub_type_id=3&product_column_ids=[73, 74]' }
    additions = { conditions: { standard: [{ col: 'id', op: '=', val: '$:sub_type_id$' }] } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions), params: params)
    assert_equal '3', data.params['sub_type_id']

    expect = [{ col: 'id', op: '=', val: '3' }]
    assert_equal expect, data.conditions
  end

  def test_basic_grid
    DB.array_expect(BASIC_DATA)
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: basic_loader)
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal 5, tester.keys.length
    assert_equal [], tester['multiselect_ids']
    assert_nil tester['tree']
    assert_nil tester['fieldUpdateUrl']
    assert_equal BASIC_EXPECTED, tester['rowDefs']
    assert_equal BASIC_EXPECTED.first.keys, tester['columnDefs'].map {|a| a['field'] }
    cols = [
      { 'headerName' => 'Id', 'field' => 'id', 'hide' => false, 'headerTooltip' => 'Id', 'enableValue' => true, 'type' => 'numericColumn', 'width' => Crossbeams::DataGrid::COLWIDTH_INTEGER },
      { 'headerName' => 'First name', 'field' => 'user_name', 'hide' => false, 'headerTooltip' => 'First name', 'width' => 150, 'enableRowGroup' => true, 'enablePivot' => true, 'pinned' => 'left' },
      { 'headerName' => 'Department name', 'field' => 'department_name', 'hide' => false, 'headerTooltip' => 'Department name', 'enableRowGroup' => true, 'enablePivot' => true },
      { 'headerName' => 'Created at', 'field' => 'created_at', 'hide' => false, 'headerTooltip' => 'Created at', 'width' => Crossbeams::DataGrid::COLWIDTH_DATETIME, 'enableRowGroup' => true, 'enablePivot' => true, 'valueFormatter' => 'crossbeamsGridFormatters.dateTimeWithoutSecsOrZoneFormatter' },
      { 'headerName' => 'Amount', 'field' => 'amount', 'hide' => false, 'headerTooltip' => 'Amount', 'enableValue' => true, 'type' => 'numericColumn', 'width' => Crossbeams::DataGrid::COLWIDTH_NUMBER, 'valueFormatter' => 'crossbeamsGridFormatters.numberWithCommas2' },
      { 'headerName' => 'Active', 'field' => 'active', 'hide' => false, 'headerTooltip' => 'Active', 'enableRowGroup' => true, 'enablePivot' => true, 'cellRenderer' => 'crossbeamsGridFormatters.booleanFormatter', 'cellClass' => 'grid-boolean-column', 'width' => Crossbeams::DataGrid::COLWIDTH_BOOLEAN }
    ]
    assert_equal cols, tester['columnDefs']
  end

  def test_multiselect
    DB.array_expect(BASIC_DATA)
    additions = { multiselect: { multitest: { grid_caption: 'Multi caption', url: '/d/e/f' } } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, multi_key: 'multitest', config_loader: loader_extended(additions))
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert tester['columnDefs'].any? { |r| r['colId'] == 'theSelector' }
    assert_equal BASIC_EXPECTED, tester['rowDefs']
    assert_equal [], tester['multiselect_ids']

    additions = { multiselect: { multitest: { grid_caption: 'Multi caption', url: '/d/e/f', preselect: 'SELECT id FROM users' } } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, multi_key: 'multitest', config_loader: loader_extended(additions), params: { id: 1 })
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal [1, 2], tester['multiselect_ids']
  end

  def test_tree
    DB.array_expect(BASIC_DATA)
    additions = { tree: { tree_column: 'tcol', tree_caption: 'The Tree', suppress_node_counts: false, groupDefaultExpanded: -1 } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions))
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal additions[:tree][:tree_column], tester['tree']['tree_column']
    assert_equal additions[:tree][:tree_caption], tester['tree']['tree_caption']
    assert_equal additions[:tree][:suppress_node_counts], tester['tree']['suppress_node_counts']
    assert_equal additions[:tree][:groupDefaultExpanded], tester['tree']['groupDefaultExpanded']
  end

  def test_actions
    DB.array_expect(BASIC_DATA)
    additions = { actions:
                  [{url: '/development/masterfiles/users/$:id$', text: 'view', icon: 'view-show', title: 'View', popup: true},
                   {url: '/development/masterfiles/users/$:id$/edit', text: 'edit', icon: 'edit', title: 'Edit',
                    auth: { function: 'security', program: 'menu', permission: 'edit'}},
                   {separator: true},
                   {url: '/development/masterfiles/users/$:id$', text: 'delete', icon: 'delete', is_delete: true, popup: true}] }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions), params: { id: '1' })
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal BASIC_EXPECTED, tester['rowDefs']
    actions_col = tester['columnDefs'].first
    expected = { 'headerName' => '',
                 'pinned' => 'left',
                 'width' => 60,
                 'suppressMenu' => true,
                 'sortable' => false,
                 'suppressMovable' => true,
                 'filter' => false,
                 'enableRowGroup' => false,
                 'enablePivot' => false,
                 'enableValue' => false,
                 'suppressCsvExport' => true,
                 'suppressColumnsToolPanel' => true,
                 'suppressFiltersToolPanel' => true,
                 'valueGetter' => "[{\"text\":\"view\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"icon\":\"view-show\",\"title\":\"View\",\"popup\":true},{\"text\":\"edit\",\"url\":\"/development/masterfiles/users/$col0$/edit\",\"col0\":\"id\",\"icon\":\"edit\",\"title\":\"Edit\"},{\"text\":\"sep01\",\"is_separator\":true},{\"text\":\"delete\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"prompt\":\"Are you sure?\",\"method\":\"delete\",\"icon\":\"delete\",\"popup\":true}]",
                 'colId' => 'action_links',
                 'cellRenderer' => 'crossbeamsGridFormatters.menuActionsRenderer'
    }
    assert_equal expected, actions_col
  end

  def test_deny_access_actions
    DB.array_expect(BASIC_DATA)
    additions = { actions:
                  [{url: '/development/masterfiles/users/$:id$', text: 'view', icon: 'view-show', title: 'View', popup: true},
                   {url: '/development/masterfiles/users/$:id$/edit', text: 'edit', icon: 'edit', title: 'Edit',
                    auth: { function: 'security', program: 'menu', permission: 'edit'} },
                   {separator: true},
                   {url: '/development/masterfiles/users/$:id$', text: 'delete', icon: 'delete', is_delete: true, popup: true}] }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: DENY_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions), params: { id: '1' })
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal BASIC_EXPECTED, tester['rowDefs']
    actions = tester['columnDefs'].first['valueGetter']
    expected = "[{\"text\":\"view\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"icon\":\"view-show\",\"title\":\"View\",\"popup\":true},{\"text\":\"sep01\",\"is_separator\":true},{\"text\":\"delete\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"prompt\":\"Are you sure?\",\"method\":\"delete\",\"icon\":\"delete\",\"popup\":true}]"
    assert_equal expected, actions
  end

  def test_has_permission_access_actions
    DB.array_expect(BASIC_DATA)
    additions = { actions:
                  [{url: '/development/masterfiles/users/$:id$', text: 'view', icon: 'view-show', title: 'View', popup: true},
                   {url: '/development/masterfiles/users/$:id$/edit', text: 'edit', icon: 'edit', title: 'Edit',
                    has_permission: [ :key1, :key2] },
                   {separator: true},
                   {url: '/development/masterfiles/users/$:id$', text: 'delete', icon: 'delete', is_delete: true, popup: true}] }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions), params: { id: '1' })
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal BASIC_EXPECTED, tester['rowDefs']
    actions = tester['columnDefs'].first['valueGetter']
    expected = "[{\"text\":\"view\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"icon\":\"view-show\",\"title\":\"View\",\"popup\":true},{\"text\":\"edit\",\"url\":\"/development/masterfiles/users/$col0$/edit\",\"col0\":\"id\",\"icon\":\"edit\",\"title\":\"Edit\"},{\"text\":\"sep01\",\"is_separator\":true},{\"text\":\"delete\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"prompt\":\"Are you sure?\",\"method\":\"delete\",\"icon\":\"delete\",\"popup\":true}]"
    assert_equal expected, actions
  end

  def test_no_permission_access_actions
    DB.array_expect(BASIC_DATA)
    additions = { actions:
                  [{url: '/development/masterfiles/users/$:id$', text: 'view', icon: 'view-show', title: 'View', popup: true},
                   {url: '/development/masterfiles/users/$:id$/edit', text: 'edit', icon: 'edit', title: 'Edit',
                    has_permission: [ :key1, :key2] },
                   {separator: true},
                   {url: '/development/masterfiles/users/$:id$', text: 'delete', icon: 'delete', is_delete: true, popup: true}] }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: NO_PERMISSION, config_loader: loader_extended(additions), params: { id: '1' })
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal BASIC_EXPECTED, tester['rowDefs']
    actions = tester['columnDefs'].first['valueGetter']
    expected = "[{\"text\":\"view\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"icon\":\"view-show\",\"title\":\"View\",\"popup\":true},{\"text\":\"sep01\",\"is_separator\":true},{\"text\":\"delete\",\"url\":\"/development/masterfiles/users/$col0$\",\"col0\":\"id\",\"prompt\":\"Are you sure?\",\"method\":\"delete\",\"icon\":\"delete\",\"popup\":true}]"
    assert_equal expected, actions
  end

  def test_popup_and_loading_window_action
    DB.array_expect(BASIC_DATA)
    additions = { actions:
                  [{url: '/development/masterfiles/users/$:id$', text: 'view', icon: 'view-show', title: 'View', popup: true, loading_window: true}]
    }
    assert_raises(ArgumentError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions), params: { id: '1' }) }

    ok_additions = { actions:
                  [{url: '/development/masterfiles/users/$:id$', text: 'view', icon: 'view-show', title: 'View', loading_window: true}]
    }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(ok_additions), params: { id: '1' })
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal BASIC_EXPECTED, tester['rowDefs']
    assert_match(/"loading_window":true/, tester['columnDefs'].first['valueGetter'])
  end

  def test_calculated_columns
    DB.array_expect(BASIC_DATA)
    additions = { calculated_columns: [{ name: 'colnew', caption: 'ColCap', date_type: :number, format: :delimited_1000, expression: 'amount * id', position: 2 }] }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions), params: { id: '1' })
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal 'colnew', tester['columnDefs'][2]['field']
    assert_equal 'data.amount * data.id', tester['columnDefs'][2]['valueGetter']
  end

  def test_edit_rules
    DB.array_expect(BASIC_DATA)
    additions = { edit_rules: { url: '/path/to/$:id$/inline_save', editable_fields: { 'user_name' => nil,
                                                                                      'amount' => { editor: :numeric },
                                                                                      'department_name' => { editor: :textarea },
                                                                                      'active' => { editor: :select, values: ['Yes', 'No'] },
                                                                                      'created_at' => { editor: :search_select, values: ['Now', 'Then', 'Soon'] } } } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions))
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal '/path/to/$:id$/inline_save', tester['fieldUpdateUrl']
    col = tester['columnDefs'].find {|c| c['field'] == 'user_name' }

    assert_equal 'agPopupTextCellEditor', col['cellEditor']
    assert_equal 'First name (editable)', col['headerTooltip']
    assert_equal 'gridEditableColumn', col['headerClass']
    assert col['editable']

    col = tester['columnDefs'].find {|c| c['field'] == 'amount' }
    assert_equal 'numericCellEditor', col['cellEditor']
    assert_equal 'Amount (editable)', col['headerTooltip']
    assert_equal 'ag-numeric-header gridEditableColumn', col['headerClass']
    assert col['editable']

    col = tester['columnDefs'].find {|c| c['field'] == 'department_name' }
    assert_equal 'agLargeTextCellEditor', col['cellEditor']
    assert col['editable']

    col = tester['columnDefs'].find {|c| c['field'] == 'active' }
    assert_equal 'agRichSelectCellEditor', col['cellEditor']
    assert_equal({ 'values' => ['Yes', 'No'], 'selectWidth' => 200 }, col['cellEditorParams'])
    assert col['editable']

    col = tester['columnDefs'].find {|c| c['field'] == 'created_at' }
    assert_equal 'searchableSelectCellEditor', col['cellEditor']
    assert_equal({ 'values' => ['Now', 'Then', 'Soon'] }, col['cellEditorParams'])
    assert col['editable']
  end

  def test_edit_select_rule
    DB.array_expect(BASIC_DATA)
    additions = { edit_rules: { url: '/path/to/$:id$/inline_save', editable_fields: { 'active' => { editor: :select, width: 350, value_sql: "SELECT t.* from (VALUES ('Yes'), ('No')) t" } } } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions))
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      data.stub(:select_editor_values, ['Yes', 'No']) do
        rows = data.list_rows
      end
    end
    tester = JSON.parse(rows)

    col = tester['columnDefs'].find {|c| c['field'] == 'active' }
    assert_equal 'agRichSelectCellEditor', col['cellEditor']
    assert_equal({ 'values' => ['Yes', 'No'], 'selectWidth' => 350 }, col['cellEditorParams'])
    assert col['editable']
  end

  def test_edit_select_rule_ok
    DB.array_expect(BASIC_DATA)
    additions = { edit_rules: { url: '/path/to/$:id$/inline_save', editable_fields: { 'active' => { editor: :select, misspelled_values: [] } } } }
    data = Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, config_loader: loader_extended(additions))
    assert_raises(ArgumentError) do
      data.stub(:load_report_def, BASIC_DM_REPORT) do
        rows = data.list_rows
      end
    end
  end
end
