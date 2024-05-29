require 'test_helper'

class SearchGridDefinitionTest < Minitest::Test

  YAML_FILES = {
    search: { file: { dataminer_definition: 'a_report' },
            render: { caption: 'List Users', is_nested: false, tree: nil, grid_params: {} }
    }
  }
  GRID_OPTS = {
    list_url: '/list/%s/grid',
    list_nested_url: '/list/%s/nested_grid',
    list_multi_url: '/list/%s/grid_multi',
    search_url: '/search/%s/grid',
    filter_url: '/search/%s',
    run_search_url: '/search/%s/run',
    run_to_excel_url: '/search/%s/xls'
  }
  BASIC_DM_REPORT = {
    :caption=>"List Users",
    :sql=>"SELECT id, name FROM users",
    :limit=>nil,
    :offset=>nil,
    :external_settings=>{},
    :columns=>
     {"id"=>
       {:name=>"id",
        :sequence_no=>1,
        :caption=>"Id",
        :namespaced_name=>"id",
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
      "name"=>
       {:name=>"name",
        :sequence_no=>2,
        :caption=>"Name",
        :namespaced_name=>"name",
        :data_type=>:string,
        :width=>nil,
        :format=>nil,
        :hide=>false,
        :groupable=>false,
        :group_by_seq=>nil,
        :group_sum=>false,
        :group_avg=>false,
        :group_min=>false,
        :group_max=>false}},
        :query_parameter_definitions=>[{ column: 'users.id',
         caption: 'ID',
         data_type: :integer,
         control_type: :text,
         default_value: nil,
         ordered_list: nil,
         ui_priority: 1,
         list_def: nil },
         { column: 'users.name',
         caption: 'Name',
         data_type: :string,
         control_type: :text,
         default_value: nil,
         ordered_list: nil,
         ui_priority: 2,
         list_def: nil },
         { column: 'users.dept',
         caption: 'Department',
         data_type: :string,
         control_type: :text,
         default_value: nil,
         ordered_list: nil,
         ui_priority: 3,
         list_def: nil }
       ]
  }

  def basic_loader
    -> { YAML_FILES[:search][:file] }
  end

  def loader_extended(additions)
    -> { YAML_FILES[:search][:file].merge(additions) }
  end

  def test_required_params
    assert_raises(KeyError) { Crossbeams::DataGrid::SearchGridDefinition.new(root_path: '/a/b/c') }
    assert_raises(KeyError) { Crossbeams::DataGrid::SearchGridDefinition.new(id: 'agrid')}
  end

  def test_basic_search
    gd = Crossbeams::DataGrid::SearchGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: {}, config_loader: basic_loader)
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal gd.grid_path, '/search/arep/grid?json_var=&limit=&offset='
      assert_equal YAML_FILES[:search][:render], gd.render_options
    end
  end

  def test_basic_search_with_params
    gd = Crossbeams::DataGrid::SearchGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: basic_loader)
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal YAML_FILES[:search][:render].merge(grid_params: { athing: 'athing' }), gd.render_options
      assert_equal ['users.id', 'users.name', 'users.dept'], gd.parameter_list.map(&:column)
    end
  end

  def test_basic_search_with_fixed_params
    additions = { fixed_parameters: [{ col: 'users.dept', op: '=', val: 'HR' }] }
    gd = Crossbeams::DataGrid::SearchGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: loader_extended(additions))
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal YAML_FILES[:search][:render].merge(grid_params: { athing: 'athing' }), gd.render_options
      assert_equal ['users.id', 'users.name'], gd.parameter_list.map(&:column)
    end
  end
end
