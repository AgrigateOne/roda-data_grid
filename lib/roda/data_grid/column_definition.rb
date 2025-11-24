# frozen_string_literal: true

module Crossbeams
  module DataGrid
    # Set attributes for a grid column
    class ColumnDefinition
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def column_hash(col) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        hs                  = { headerName: col.caption, field: col.name, hide: col.hide, headerTooltip: col.caption, context: {} }
        hs[:hide]           = true if config.hide_for_client.include?(col.name)
        hs[:width]          = col.width + 10 unless col.width.nil?
        hs[:width]          = Crossbeams::DataGrid::COLWIDTH_DATETIME if col.width.nil? && col.data_type == :datetime
        hs[:enableValue]    = true if %i[integer number].include?(col.data_type)
        hs[:enableRowGroup] = true unless config.tree || hs[:enableValue] && !col.groupable
        hs[:enablePivot]    = true unless config.tree || hs[:enableValue] && !col.groupable
        hs[:rowGroupIndex]  = col.group_by_seq if col.group_by_seq
        hs[:pinned]         = col.pinned if col.pinned
        hs[:rowGroup]       = true if col.group_by_seq
        hs[:aggFunc]        = 'sum' if col.group_sum
        hs[:cellDataType] = case col.data_type
                            when :integer, :number
                              'number'
                            when :boolean
                              'boolean'
                            when :date
                              'dateString'
                            when :datetime
                              'dateTimeString'
                            else
                              'text'
                            end

        if %i[integer number].include?(col.data_type)
          hs[:type]      = 'numericColumn'
          hs[:width]     = Crossbeams::DataGrid::COLWIDTH_INTEGER if col.width.nil? && col.data_type == :integer
          hs[:width]     = Crossbeams::DataGrid::COLWIDTH_NUMBER if col.width.nil? && col.data_type == :number
        end
        hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas2' if col.format == :delimited_1000 # rubocop:disable Naming/VariableNumber
        hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas4' if col.format == :delimited_1000_4 # rubocop:disable Naming/VariableNumber
        hs[:valueFormatter] = 'crossbeamsGridFormatters.localCurrencyFormatter' if col.format == :local_currency
        if col.data_type == :boolean
          hs[:cellRenderer] = 'agCheckboxCellRenderer' # 'crossbeamsGridFormatters.booleanFormatter'
          # hs[:cellClass]    = 'grid-boolean-column'
          hs[:width]        = Crossbeams::DataGrid::COLWIDTH_BOOLEAN if col.width.nil?
        end
        hs[:valueFormatter] = 'crossbeamsGridFormatters.dateTimeWithoutSecsOrZoneFormatter' if col.data_type == :datetime
        hs[:valueFormatter] = 'crossbeamsGridFormatters.dateTimeWithoutZoneFormatter' if col.format == :datetime_with_secs
        hs[:cellRenderer] = 'crossbeamsGridFormatters.iconFormatter' if col.name == 'icon'
        hs[:cellRenderer] = 'crossbeamsGridFormatters.barColourFormatter' if col.format == :bar_colour

        # Sparkline chart formats
        if SPARKTYPES.keys.include?(col.format)
          hs[:cellRenderer] = 'agSparklineCellRenderer'
          hs[:cellRendererParams] = { sparklineOptions: { type: SPARKTYPES[col.format] } }
          @multi_dimensional_arrays << col.name.to_sym if col.format.to_s.end_with?('_text')

          if col.format == :sparkbar_perc
            @percentage_bars << col.name.to_sym
            hs[:cellRendererParams] = {
              sparklineOptions: {
                type: SPARKTYPES[col.format],
                valueAxisDomain: [0, 100],
                label: {
                  enabled: true,
                  placement: 'outsideEnd'
                },
                padding: {
                  top: 0,
                  bottom: 0
                }
              }
            }
          end
        end
        hs
      end

      def calculated_column(raw) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        col = OpenStruct.new(raw)
        hs = { headerName: col.caption, field: col.name, headerTooltip: col.caption, context: {} }
        hs[:width] = col.width unless col.width.nil?
        hs[:enableValue] = true if %i[integer number].include?(col.data_type)

        if %i[integer number].include?(col.data_type)
          hs[:type]      = 'numericColumn'
          hs[:width]     = Crossbeams::DataGrid::COLWIDTH_INTEGER if col.width.nil? && col.data_type == :integer
          hs[:width]     = Crossbeams::DataGrid::COLWIDTH_NUMBER if col.width.nil? && col.data_type == :number
        end
        hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas2' if col.format == :delimited_1000 # rubocop:disable Naming/VariableNumber
        hs[:valueFormatter] = 'crossbeamsGridFormatters.numberWithCommas4' if col.format == :delimited_1000_4 # rubocop:disable Naming/VariableNumber
        hs[:valueFormatter] = 'crossbeamsGridFormatters.localCurrencyFormatter' if col.format == :local_currency
        parts = col.expression.split(' ')
        hs[:valueGetter] = parts.map { |p| %w[* + - /].include?(p) ? p : "data.#{p}" }.join(' ')
        [col.position || 1, hs]
      end
    end
  end
end
