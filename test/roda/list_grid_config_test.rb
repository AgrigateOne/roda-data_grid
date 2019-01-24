require 'test_helper'

class ListGridConfigTest < Minitest::Test

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
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridConfig.new({}) }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridConfig.new(root_path: '/a/b/c') }
    assert_raises(KeyError) { Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid') }
  end

  def test_defaults
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', config_loader: basic_loader)
    assert_equal 'agrid', config.id
    assert_equal '/a/b/c', config.root
    assert_equal 'a_report', config.dataminer_definition
    assert_nil config.multiselect_key
    assert_nil config.fit_height
    assert_nil config.grid_caption
    assert_nil config.tree
    assert_nil config.actions
    assert_equal [], config.page_control_defs
    assert_equal({}, config.multiselect_opts)
    assert_equal [], config.conditions
    refute config.nested_grid
  end

  def test_grid_caption
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { athing: 'athing' }, config_loader: basic_loader)
    assert_nil config.grid_caption

    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { athing: 'athing' }, config_loader: basic_loader, grid_caption: 'Grid caption')
    assert_equal 'Grid caption', config.grid_caption

    additions = { grid_caption: 'List caption' }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { athing: 'athing' }, config_loader: loader_extended(additions))
    assert_equal 'List caption', config.grid_caption

    additions = { multiselect: { multitest: { grid_caption: 'Multi caption', url: '/d/e/f' } } }

    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', multi_key: 'multitest',  params: { athing: 'athing' }, config_loader: loader_extended(additions))
    assert_equal 'Multi caption', config.grid_caption
  end

  def test_fit_height
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { fit_height: true, athing: 'athing' }, config_loader: basic_loader)
    assert config.fit_height
  end

  def test_tree
    additions = { tree: { tree_column: 'tcol', tree_caption: 'The Tree', suppress_node_counts: false, groupDefaultExpanded: -1 } }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { athing: 'athing' }, config_loader: loader_extended(additions))
    assert_equal 'The Tree', config.tree[:tree_caption]
  end

  def test_multiselect
    additions = { multiselect: { multitest: { grid_caption: 'Multi caption', url: '/d/e/f' } } }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { athing: 'athing' }, multi_key: 'multitest', config_loader: loader_extended(additions))
    assert config.multiselect
    assert_equal :multitest, config.multiselect_key
    assert_equal '/d/e/f', config.multiselect_opts[:url]
  end

  def test_conditions
    additions = { conditions: { standard: [{ col: 'id', op: '=', val: '$:id$' }] } }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { query_string: 'key=standard&sub_type_id=3&product_column_ids=[73, 74]' }, config_loader: loader_extended(additions))
    assert_equal :standard, config.conditions_key
    assert_equal 1, config.conditions.length
    assert_equal 'id', config.conditions.first[:col]

    # Test when params are not part of querystring:
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { key: 'standard', sub_type_id: '3', product_column_ids: '[73, 74]' }, config_loader: loader_extended(additions))
    assert_equal :standard, config.conditions_key
    assert_equal 1, config.conditions.length
    assert_equal 'id', config.conditions.first[:col]

    # Test missmatched key and conditions - raises informative error.
    assert_raises(ArgumentError) { Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { key: 'somethingelse', sub_type_id: '3', product_column_ids: '[73, 74]' }, config_loader: loader_extended(additions)) }
  end

  def test_multisel_conditions
    additions = { conditions: { standard: [{ col: 'id', op: '=', val: '$:id$' }] },
                  multiselect: { multitest: { grid_caption: 'Multi caption', url: '/d/e/f', conditions: 'standard' } } }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { some_parm: 'something' }, multi_key: 'multitest', config_loader: loader_extended(additions))
    assert_nil config.conditions_key
    assert_equal 1, config.conditions.length
    assert_equal 'id', config.conditions.first[:col]
  end

  def test_actions
    additions = { actions: [{ url: "/masterfiles/fruit/fruit_size_references/$:id$", text: 'view', icon: 'view-show', title: 'View', popup: true },
                            { url: "/masterfiles/fruit/fruit_size_references/$:id$/edit", text: 'edit', icon: 'edit', title: 'Edit', popup: true }]
    }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { some_parm: 'something' }, config_loader: loader_extended(additions))
    assert_equal 2, config.actions.length
    assert_equal 'Edit', config.actions.last[:title]
  end

  def test_page_controls
    additions = { page_controls: [{ control_type: :link,
                                    url: "/pack_material/locations/locations/new",
                                    text: 'New Location',
                                    style: :button,
                                    behaviour: :popup,
                                    hide_if_sql_returns_true: 'SELECT EXISTS(SELECT id FROM locations)' }] }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { some_parm: 'something' }, config_loader: loader_extended(additions))
    assert_equal 1, config.page_control_defs.length
    assert_equal 'New Location', config.page_control_defs.last[:text]
  end

  def test_nested
    # Note nesting works, but is cumbersome and currently not used in any implementation.
    # Therefore this test is rudimentary, to be extended if nesting is brought back.
    additions = { nesting: { keys: [:one_id, :two_id] } }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { athing: 'athing' }, config_loader: loader_extended(additions))
    assert config.nested_grid
  end

  def test_calculated_columns
    additions = { calculated_columns: [{ name: 'colnew', caption: 'ColCap', date_type: :number, format: :delimited_1000, expression: 'col1 * col2', position: 2 }]
    }
    config = Crossbeams::DataGrid::ListGridConfig.new(id: 'agrid', root_path: '/a/b/c', params: { some_parm: 'something' }, config_loader: loader_extended(additions))
    assert_equal 1, config.calculated_columns.length
    assert_equal 'ColCap', config.calculated_columns.last[:caption]
  end
end
