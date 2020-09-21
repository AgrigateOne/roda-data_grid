require 'test_helper'

class ColumnDefinerTest < Minitest::Test
  def test_column_basics
    default_false = %i[hide]
    default_true = %i[enableRowGroup enablePivot]
    default_not_set = %i[width enableValue rowGroupIndex rowGroup cellRenderer pinned editable cellEditor cellEditorParams]

    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.col 'afield', 'A Caption'
    end
    col = cols.first

    assert_equal col[:headerName], 'A Caption'
    assert_equal col[:headerTooltip], 'A Caption'
    assert_equal col[:field], 'afield'

    default_false.each { |d| refute col[d] }
    default_true.each { |d| assert col[d] }
    default_not_set.each { |d| assert_nil col[d] }
  end

  def test_column_captions
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.col 'afield', 'A Caption'
      mk.col 'another_field'
      mk.col 'field3', nil, tooltip: 'A different tooltip'
    end
    col = cols.first
    assert_equal col[:headerName], 'A Caption'
    assert_equal col[:headerTooltip], 'A Caption'

    col = cols[1]
    assert_equal col[:headerName], 'Another field'
    assert_equal col[:headerTooltip], 'Another field'

    col = cols.last
    assert_equal col[:headerName], 'Field3'
    assert_equal col[:headerTooltip], 'A different tooltip'
  end

  def test_integer_basics
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.integer 'afield', 'A Caption'
    end
    col = cols.first

    assert_equal col[:headerName], 'A Caption'
    assert_equal col[:headerTooltip], 'A Caption'
    assert_equal col[:field], 'afield'
    assert_equal col[:cellClass], 'grid-number-column'
    assert_equal col[:width], 100
  end

  def test_integer_with_overrides
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.integer 'afield', 'A Caption', width: 400, data_type: :ignored
    end
    col = cols.first

    assert_equal col[:width], 400
  end

  def test_numeric_basics
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.numeric 'afield', 'A Caption'
    end
    col = cols.first

    assert_equal col[:headerName], 'A Caption'
    assert_equal col[:headerTooltip], 'A Caption'
    assert_equal col[:field], 'afield'
    assert_equal col[:cellClass], 'grid-number-column'
    assert_equal col[:width], 120
    assert_equal col[:valueFormatter], 'crossbeamsGridFormatters.numberWithCommas2'
  end

  def test_numeric_with_overrides
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.numeric 'afield', 'A Caption', format: nil, width: 400, data_type: :ignored
    end
    col = cols.first

    assert_equal col[:width], 400
    assert_nil col[:cellRenderer]
  end

  def test_boolean_basics
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.boolean 'afield', 'A Caption'
    end
    col = cols.first

    assert_equal col[:headerName], 'A Caption'
    assert_equal col[:headerTooltip], 'A Caption'
    assert_equal col[:field], 'afield'
    assert_equal col[:cellClass], 'grid-boolean-column'
    assert_equal col[:width], 100
    assert_equal col[:cellRenderer], 'crossbeamsGridFormatters.booleanFormatter'
  end

  def test_boolean_with_overrides
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.boolean 'afield', 'A Caption', width: 400, data_type: :ignored
    end
    col = cols.first

    assert_equal col[:width], 400
  end

  def test_editable_column
    cd = Crossbeams::DataGrid::ColumnDefiner.new
    cols = cd.make_columns do |mk|
      mk.col 'afield', nil, editable: true
    end
    col = cols.first

    assert col[:editable]
    assert_nil col[:cellEditor]
    assert_nil col[:cellEditorParams]

    cols = cd.make_columns do |mk|
      mk.col 'afield', nil, editable: true,
             cellEditor: 'select',
             cellEditorParams: { values: ['true', 'false'] }
    end
    col = cols.first

    assert col[:editable]
    assert_equal col[:cellEditor], 'agRichSelectCellEditor'
    assert_equal col[:cellEditorParams], { values: ['true', 'false'], selectWidth: 200 }

    cols = cd.make_columns do |mk|
      mk.col 'afield', nil, editable: true,
             cellEditor: 'select',
             cellEditorParams: { values: ['true', 'false'], width: 350 }
    end
    col = cols.first

    assert_equal col[:cellEditorParams], { values: ['true', 'false'], selectWidth: 350 }

    cols = cd.make_columns do |mk|
      mk.col 'afield', nil, editable: true,
             cellEditor: 'search_select',
             cellEditorParams: { values: ['true', 'false'] }
    end
    col = cols.first

    assert col[:editable]
    assert_equal col[:cellEditor], 'searchableSelectCellEditor'
    assert_equal col[:cellEditorParams], { values: ['true', 'false'] }

    cols = cd.make_columns do |mk|
      mk.numeric 'afield', nil, editable: true
    end
    col = cols.first

    assert col[:editable]
    assert_equal 'numericCellEditor', col[:cellEditor]
    assert_nil col[:cellEditorType]

    cols = cd.make_columns do |mk|
      mk.integer 'afield', nil, editable: true
    end
    col = cols.first

    assert col[:editable]
    assert_equal 'numericCellEditor', col[:cellEditor]
    assert_equal 'integer',  col[:cellEditorType]
  end
end
