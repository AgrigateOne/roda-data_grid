require 'test_helper'

class ListGridDefinitionTest < Minitest::Test

  YAML_FILES = {
    list: { file: { dataminer_definition: 'a_report' },
            render: { caption: 'List Users', is_nested: false, tree: nil, grid_params: nil }
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
         list_def: nil }
       ]
  }

  # def replace_read_file(gd, key, additions = {})
  #   gd.instance_variable_set(:@key_for_test, key)
  #   gd.instance_variable_set(:@additions, additions)
  #   def gd.read_file
  #     YAML_FILES[@key_for_test][:file].merge(@additions).to_yaml
  #   end
  # end

  # def replace_report(gd)
  #   def gd.load_report_def(file_name)
  #     BASIC_DM_REPORT
  #   end
  # end

  def basic_loader
    -> { YAML_FILES[:list][:file] }
  end

  def loader_extended(additions)
    -> { YAML_FILES[:list][:file].merge(additions) }
  end

  def test_required_params
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c') }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridDefinition.new(id: 'agrid')}
  end

  def test_basic_list
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', config_loader: basic_loader)
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal gd.grid_path, '/list/arep/grid'
      assert_equal YAML_FILES[:list][:render], gd.render_options
    end
  end

  def test_basic_list_with_params
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: basic_loader)
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal YAML_FILES[:list][:render].merge(grid_params: { athing: 'athing' }), gd.render_options
    end
  end

  def test_fit_height
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', id: 'agrid', grid_opts: GRID_OPTS, config_loader: basic_loader)
    refute gd.fit_height

    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', id: 'agrid', grid_opts: GRID_OPTS, config_loader: basic_loader, params: { fit_height: true, something_else: 1 })
    assert gd.fit_height
    assert_equal({ something_else: 1 }, gd.instance_variable_get(:@params))
  end

  def test_page_controls
    DB.array_expect(:get_bool)
    additions = {page_controls: [{ control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup },
                                 { control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup, hide_if_sql_returns_true: 'SELECT true' },
                                 { control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup, hide_if_sql_returns_true: 'SELECT false' }]}
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: loader_extended(additions))
    expect = [{ control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup },
              { control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup, hide_if_sql_returns_true: 'SELECT false' } ]
    pc = []
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      pc = gd.page_controls
      assert_equal expect, pc
    end
  end

  def test_page_controls_hidden_by_params
    additions = { conditions: { hideme: [{ col: 'users.id', op: '=', val: 1 }] },
                  page_controls: [{ control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup },
                                 { control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup, hide_for_key: ['NA', 'AN'] },
                                 { control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup, hide_for_key: 'hideme' }]}
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { key: 'hideme', athing: 'athing' }, config_loader: loader_extended(additions))
    expect = [{ control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup },
              { control_type: :link, url: '/d/e/f', text: 'Blah', style: :button, behaviour: :popup, hide_for_key: ['NA', 'AN'] } ]
    pc = []
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      pc = gd.page_controls
      assert_equal expect, pc
    end
  end

  def test_grid_caption
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: basic_loader)
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal 'List Users', gd.render_options[:caption]
    end

    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: basic_loader, grid_caption: 'Grid caption')
      gd.stub(:load_report_def, BASIC_DM_REPORT) do
    assert_equal 'Grid caption', gd.render_options[:caption]
    end

    additions = { captions: { grid_caption: 'List caption' } }
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: loader_extended(additions))
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal 'List caption', gd.render_options[:caption]
    end

    additions = { captions: { grid_caption: 'List caption', conditions: { standard: 'Some other caption' } }, conditions: { standard: [{ col: 'users.id', op: '=', val: '$:id$' }] } }
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { key: 'standard', id: 21 }, config_loader: loader_extended(additions))
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal 'Some other caption', gd.render_options[:caption]
    end

    additions = { multiselect: { multitest: { grid_caption: 'Multi caption', url: '/d/e/f' } } }

    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', multi_key: 'multitest',  params: { athing: 'athing' }, config_loader: loader_extended(additions))
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_equal 'Multi caption', gd.render_options[:caption]
    end
  end

  def test_colour_key
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: basic_loader)
    gd.stub(:load_report_def, BASIC_DM_REPORT) do
      assert_nil gd.render_options[:colour_key]
    end

    key = { 'green' => 'GO', 'red' => 'STOP' }
    gd = Crossbeams::DataGrid::ListGridDefinition.new(root_path: '/a/b/c', grid_opts: GRID_OPTS, id: 'arep', params: { athing: 'athing' }, config_loader: basic_loader)
    gd.stub(:load_report_def, BASIC_DM_REPORT.merge(external_settings: { colour_key: key })) do
      assert_equal key, gd.render_options[:colour_key]
    end
  end
end
