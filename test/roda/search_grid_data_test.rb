require 'test_helper'
require 'bigdecimal'

class Roda
  module RodaPlugins
    module DataGrid
      class Error < StandardError; end
    end
  end
end
class SearchGridDataTest < Minitest::Test
BASIC_DATA = [
  { 'id': 1, 'user_name': 'Fred', 'department_name': 'IT', 'created_at': Time.new(2018,9,01,13,40), 'amount': BigDecimal('12.34'), 'active': true },
  { 'id': 2, 'user_name': 'John', 'department_name': 'Finance', 'created_at': Time.new(2018,9,02,15,24), 'amount': BigDecimal('94.0212121'), 'active': false }
]
BASIC_EXPECTED = [
  { 'id' => 1, 'user_name' => 'Fred', 'department_name' => 'IT', 'created_at' => Time.new(2018,9,01,13,40).to_s, 'amount' => 12.34, 'active' => true },
  { 'id' => 2, 'user_name' => 'John', 'department_name' => 'Finance', 'created_at' => Time.new(2018,9,02,15,24).to_s, 'amount' => 94.0212121, 'active' => false }
]
FRED_EXPECTED = [
  { 'id' => 1, 'user_name' => 'Fred', 'department_name' => 'IT', 'created_at' => Time.new(2018,9,01,13,40).to_s, 'amount' => 12.34, 'active' => true }
]
JOHN_EXPECTED = [
  { 'id' => 2, 'user_name' => 'John', 'department_name' => 'Finance', 'created_at' => Time.new(2018,9,02,15,24).to_s, 'amount' => 94.0212121, 'active' => false }
]
FINANCE_EXPECTED = [
  { 'id' => 2, 'user_name' => 'John', 'department_name' => 'Finance', 'created_at' => Time.new(2018,9,02,15,24).to_s, 'amount' => 94.0212121, 'active' => false }
]
HR_EXPECTED = []

ALLOW_ACCESS = ->(function, program, permission) { false }
DENY_ACCESS = ->(function, program, permission) { true }
TRUE_CLIENT_RULE = ->(args) { true }
FALSE_CLIENT_RULE = ->(args) { false }

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

  YAML_FILES = {
    search: { file: { dataminer_definition: 'a_report' }
    }
  }
  def basic_loader
    -> { YAML_FILES[:search][:file] }
  end

  def loader_extended(additions)
    -> { YAML_FILES[:search][:file].merge(additions) }
  end

  def test_required_options
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new({}) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(root_path: '/a/b/c') }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid') }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', deny_access: ALLOW_ACCESS) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, client_rule_check: FALSE_CLIENT_RULE) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c', has_permission: HAS_PERMISSION) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridData.new(id: 'agrid', root_path: '/a/b/c') }
  end

  def test_basic
    data = Crossbeams::DataGrid::SearchGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, client_rule_check: FALSE_CLIENT_RULE, config_loader: basic_loader)
    assert_nil data.params
  end

  def test_basic_rows
    DB.array_expect(BASIC_DATA)
    data = Crossbeams::DataGrid::SearchGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, client_rule_check: FALSE_CLIENT_RULE, params: { json_var: '{}' }, config_loader: basic_loader)
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      rows = data.list_rows
    end
    tester = JSON.parse(rows)
    assert_equal 4, tester.keys.length
    assert_equal [], tester['multiselect_ids']
    assert_nil tester['tree']
    assert_equal BASIC_EXPECTED, tester['rowDefs']
  end

  # params={json_var="[{\"col\":\"qc_samples.qc_sample_type_id\",\"op\":\"=\",\"opText\":\"is\",\"val\":\"1\",\"valTo\":\"\",\"text\":\"100_fruit_sample\",\"textTo\":\"\",\"caption\":\"Qc sample type\"}]" limit= offset=}
  def test_filter_name
    DB.array_expect(BASIC_DATA)
    data = Crossbeams::DataGrid::SearchGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, client_rule_check: FALSE_CLIENT_RULE, params: { json_var: '[{"col":"users.user_name","op":"=","val":"Fred"}]' }, config_loader: basic_loader)
    rows = nil
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      data.list_rows
      assert data.report.runnable_sql.include?("WHERE users.user_name = 'Fred'")
    end

    data = Crossbeams::DataGrid::SearchGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, client_rule_check: FALSE_CLIENT_RULE, params: { json_var: '[{"col":"users.user_name","op":"=","val":"John"}]' }, config_loader: basic_loader)
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      data.list_rows
      assert data.report.runnable_sql.include?("WHERE users.user_name = 'John'")
    end

    additions = { fixed_parameters: [{ col: 'invalid_column_name', op: '=', val: 12 }] }
    data = Crossbeams::DataGrid::SearchGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, client_rule_check: FALSE_CLIENT_RULE, params: { json_var: '[{"col":"users.user_name","op":"=","val":"John"}]' }, config_loader: loader_extended(additions))
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_raises(Roda::RodaPlugins::DataGrid::Error) { data.list_rows }
      # assert data.report.runnable_sql.include?("WHERE users.department_id = 12 AND users.user_name = 'John'")
    end

    additions = { fixed_parameters: [{ col: 'users.department_id', op: '=', val: 12 }] }
    data = Crossbeams::DataGrid::SearchGridData.new(id: 'agrid', root_path: '/a/b/c', deny_access: ALLOW_ACCESS, has_permission: HAS_PERMISSION, client_rule_check: FALSE_CLIENT_RULE, params: { json_var: '[{"col":"users.user_name","op":"=","val":"John"}]' }, config_loader: loader_extended(additions))
    data.stub(:load_report_def, BASIC_DM_REPORT) do
      data.list_rows
      assert data.report.runnable_sql.include?("WHERE users.department_id = 12 AND users.user_name = 'John'")
    end
  end
end
