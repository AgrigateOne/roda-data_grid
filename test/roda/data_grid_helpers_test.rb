require 'test_helper'
require_relative '../../lib/roda/data_grid/data_grid_helpers'

class DataGridHelpersTest < Minitest::Test
  include Roda::DataGrid::DataGridHelpers

  def test_make_options
    [
      { in: [1, 2, 3], out: ['<option value="1">1</option>', '<option value="2">2</option>', '<option value="3">3</option>'].join("\n") },
      { in: [['one', 1], ['two', 2], ['three', 3]], out: ['<option value="1">one</option>', '<option value="2">two</option>', '<option value="3">three</option>'].join("\n") },
      { in: ['one', 'two', 'three'], out: ['<option value="one">one</option>', '<option value="two">two</option>', '<option value="three">three</option>'].join("\n") }
    ].each { |a| assert_equal a[:out], make_options(a[:in]) }
  end

  def test_build_operators
    expect = ['is', 'is not', 'greater than', 'less than', 'greater than or equal to', 'less than or equal to', 'is blank', 'is NOT blank']
    assert_equal expect, build_operators(:list).map(&:first)

    expect = ['between', 'is', 'is not', 'greater than', 'less than', 'greater than or equal to', 'less than or equal to', 'is blank', 'is NOT blank']
    assert_equal expect, build_operators(:daterange).map(&:first)

    expect = ['is', 'is not', 'greater than', 'less than', 'greater than or equal to', 'less than or equal to', 'is blank', 'is NOT blank', 'starts with', 'ends with', 'contains']
    assert_equal expect, build_operators(:text).map(&:first)
  end

  def test_list_values
    # queryParam - fixed list
    qp1 = Crossbeams::Dataminer::QueryParameterDefinition.create_from_hash(
          column: 'users.user_name',
          caption: 'Login name',
          data_type: :string,
          control_type: :text,
          default_value: nil,
          ordered_list: nil,
          ui_priority: 1,
          list_def: ['one', 'two'])
    assert_equal ['one', 'two'], build_list_values(qp1, nil)

    # queryParam - lookup list
    qp2 = Crossbeams::Dataminer::QueryParameterDefinition.create_from_hash(
          column: 'users.department_id',
          caption: 'Department',
          data_type: :integer,
          control_type: :list,
          default_value: nil,
          ordered_list: 44,
          ui_priority: 1,
          list_def: 'SELECT department_name, id FROM departments ORDER BY department_name')
    DB.array_expect([{ id: 1, nm: 'fred' }, { id: 2, nm: 'john' }])
    assert_equal [[1, 'fred'], [2, 'john']], build_list_values(qp2, DB)
  end

  def test_make_qp_json
    qp1 = Crossbeams::Dataminer::QueryParameterDefinition.create_from_hash(
          column: 'users.user_name',
          caption: 'Login name',
          data_type: :string,
          control_type: :text,
          default_value: nil,
          ordered_list: nil,
          ui_priority: 1,
          list_def: ['one', 'two'])
    qp2 = Crossbeams::Dataminer::QueryParameterDefinition.create_from_hash(
          column: 'users.department_id',
          caption: 'Department',
          data_type: :integer,
          control_type: :list,
          default_value: nil,
          ordered_list: 44,
          ui_priority: 1,
          list_def: 'SELECT department_name, id FROM departments ORDER BY department_name')
    qp3 = Crossbeams::Dataminer::QueryParameterDefinition.create_from_hash(
          column: 'users.id',
          caption: 'ID',
          data_type: :integer,
          control_type: :text,
          default_value: nil,
          ordered_list: nil,
          ui_priority: 1,
          list_def: nil)

    int_ops = [['is', '='], ['is not', '<>'], ['greater than', '>'], ['less than', '<'], ['greater than or equal to', '>='],
               ['less than or equal to', '<='], ['is blank', 'is_null'], ['is NOT blank', 'not_null']]
    str_ops = int_ops + [['starts with', 'starts_with'], ['ends with', 'ends_with'], ['contains', 'contains']]

    expect = {
      'users.user_name' => {'column' => 'users.user_name', 'caption' => 'Login name', 'default_value' => nil, 'data_type' => 'string', 'control_type' => 'text', 'operator' => str_ops },
      'users.department_id' => {'column' => 'users.department_id', 'caption' => 'Department', 'default_value' => nil, 'data_type' => 'integer', 'control_type' => 'list',
                                'list_values' => [[1, 'fred'], [2, 'john']], 'operator' => int_ops},
      'users.id' => {'column' => 'users.id', 'caption' => 'ID', 'default_value' => nil, 'data_type' => 'integer', 'control_type' => 'text', 'operator' => str_ops }
    }

    DB.array_expect([{ id: 1, nm: 'fred' }, { id: 2, nm: 'john' }])
    result = JSON.parse(make_query_param_json([qp1, qp2, qp3], DB))
    assert_equal expect, result
  end
end
