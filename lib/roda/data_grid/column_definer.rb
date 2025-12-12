# frozen_string_literal: true

module Crossbeams
  module DataGrid
    # This class provides a DSL for building up column definitions for data grids.
    #
    # Example of usage:
    #   cd = Crossbeams::DataGrid::ColumnDefiner.new
    #   cols = cd.make_columns do |mk|
    #     mk.action_column do |act|
    #       act.view_link 'view_path'
    #       act.separator
    #       act.submenu('Sub') do |sub|
    #         sub.popup_edit_link '/edit_path/$col1$', col1: 'id'
    #         sub.separator
    #         sub.popup_delete_link '/delete_path/$col1$', col1: 'id', prompt: 'Delete this?'
    #       end
    #     end
    #     mk.integer 'id', 'ID', hide: true
    #     mk.col 'code', 'The code'
    #     mk.col 'description', nil, width: 200
    #     mk.numeric 'total'
    #     mk.boolean 'active'
    #     mk.calculated_column 'tot', 'Total', type: :number, format: :delimited_1000, expression: "qty * price"
    #   end
    #
    #   # Return JSON definition of data grid:
    #   { columnDefs: cols, rowDefs: method_to_populate_rows }.to_json
    class ColumnDefiner
      attr_reader :multi_dimensional_arrays, :percentage_bars

      # New
      # @param for_multiselect [bool] do we need a checkbox column for multiselect? Default is false.
      # @param for_tree [bool] is this a tree? Default is false. Only required if `for_multiselect` is true.
      def initialize(for_multiselect: false, for_tree: false)
        @for_multiselect = for_multiselect
        @for_tree = for_tree
        @multi_dimensional_arrays = []
        @percentage_bars = []
      end

      # Main DSL method.
      #
      # @yield [mk] self - the object on which other DSL methodds can be called in the block.
      # @return [Array] all the column definitions created inside the block.
      def make_columns
        @columns = []
        yield self
        @columns
      end

      # Create a column definition from a Crossbeams::Dataminer::Column.
      #
      # @param col [Crossbeams::Dataminer::Column] the report column
      # @return [void]
      def column_from_dataminer(col) # rubocop:disable Metrics/AbcSize
        hs = {}
        hs[:hide]         = col.hide
        hs[:width]        = col.width unless col.width.nil?
        hs[:data_type]    = col.data_type
        hs[:groupable]    = col.groupable
        hs[:group_by_seq] = col.group_by_seq if col.group_by_seq
        hs[:group_sum]    = col.group_sum if col.group_sum
        hs[:group_min]    = col.group_min if col.group_min
        hs[:group_max]    = col.group_max if col.group_max
        hs[:group_avg]    = col.group_avg if col.group_avg
        hs[:format]       = col.format if col.format
        col(col.name, col.caption, hs)
      end

      # DSL method for building up action items making up an action column.
      #
      # @yield [mk] self - the object on which other DSL methodds can be called in the block.
      # @return [Hash] the action column definition.
      def action_column
        @actions = []
        yield self
        @columns << {
          headerName: '', pinned: 'left',
          width: 60,
          suppressHeaderMenuButton: true,   sortable: false,   suppressMovable: true,
          filter: false, enableRowGroup: false,   enablePivot: false,
          enableValue: false, suppressColumnsToolPanel: true,
          context: { suppressCsvExport: true },
          suppressFiltersToolPanel: true,
          valueGetter: @actions.to_json.to_s,
          colId: 'action_links',
          cellStyle: { 'padding-left': '0px', 'padding-right': '0px' }, # Remove padding so the button fills the cell, presenting a better target
          cellRenderer: 'crossbeamsGridFormatters.menuActionsRenderer'
        }
      end

      # DSL method for building up action items as sub-items of another item.
      # Adds all the action definitions created inside the block to the action list.
      #
      # @yield [mk] self - the object on which other DSL methodds can be called in the block.
      # @return [void]
      def submenu(text)
        hold_actions = @actions.dup
        @actions = []
        yield self
        hold_actions << { text: text, is_submenu: true, items: @actions }
        @actions = hold_actions
      end

      # Create a separator line in an action list.
      #
      # @return [void]
      def separator
        @actions << { is_separator: true }
      end

      # Create a link in an action list.
      #
      # @param text [String] the text to be displayed in the link.
      # @param url [String] the url to be called when the link is clicked.
      # @param options [Hash] options.
      # @return [void]
      def link(text, url, options = {})
        @actions << options.merge(text: text, url: url)
      end

      # Create a popup link in an action list.
      #
      # @param text [String] the text to be displayed in the link.
      # @param url [String] the url to be called when the link is clicked.
      # @param [Hash] options.
      # @return [void]
      def popup_link(text, url, options = {})
        @actions << options.merge(text: text, url: url, popup: true)
      end

      # Create a remote link in an action list.
      #
      # @param text [String] the text to be displayed in the link.
      # @param url [String] the url to be called when the link is clicked.
      # @param [Hash] options.
      # @return [void]
      def remote_link(text, url, options = {})
        @actions << options.merge(text: text, url: url, popup: true, method: 'post')
      end

      # Create a popup link in an action list for a view-only action.
      #
      # @param url [String] the url to be called when the link is clicked.
      # @param [Hash] options.
      # @option options [String] :text ('view') the text to be displayed in the link.
      # @option options [String] :title ('View') the text to be displayed in the link.
      # @option options [String] :icon ('view_show') the favicon to be displayed next to the link.
      # @return [void]
      def popup_view_link(url, options = {})
        soft_opts = { text: 'view', icon: 'view-show', title: 'View' }
        @actions << soft_opts.merge(options).merge(url: url, popup: true)
      end

      def view_link(url, options = {})
        soft_opts = { text: 'view', icon: 'view-show' }
        @actions << soft_opts.merge(options).merge(url: url)
      end

      def popup_new_link(url, options = {})
        soft_opts = { text: 'new', icon: 'add-solid', title: 'New' }
        @actions << soft_opts.merge(options).merge(url: url, popup: true)
      end

      def new_link(url, options = {})
        soft_opts = { text: 'new', icon: 'add-solid' }
        @actions << soft_opts.merge(options).merge(url: url)
      end

      def popup_edit_link(url, options = {})
        soft_opts = { text: 'edit', icon: 'edit', title: 'Edit' }
        @actions << soft_opts.merge(options).merge(url: url, popup: true)
      end

      def edit_link(url, options = {})
        soft_opts = { text: 'edit', icon: 'edit' }
        @actions << soft_opts.merge(options).merge(url: url)
      end

      def popup_delete_link(url, options = {})
        soft_opts = { text: 'delete',
                      prompt: 'Are you sure?',
                      method: 'delete',
                      icon: 'delete' }
        @actions << soft_opts.merge(options).merge(url: url, popup: true)
      end

      def delete_link(url, options = {})
        soft_opts = { text: 'delete',
                      prompt: 'Are you sure?',
                      method: 'delete',
                      icon: 'delete' }
        @actions << soft_opts.merge(options).merge(url: url)
      end

      def href(link, field, options = {})
        default_renderer = options[:fetch_renderer] ? 'crossbeamsGridFormatters.hrefSimpleFetchFormatter' : 'crossbeamsGridFormatters.hrefSimpleFormatter'
        @columns << {
          headerName: '',
          width: options[:width] || 60,
          suppressHeaderMenuButton: true,   sortable: false,   suppressMovable: true,
          filter: false, enableRowGroup: false,   enablePivot: false,
          enableValue: false, suppressColumnsToolPanel: true,
          context: { suppressCsvExport: true },
          suppressFiltersToolPanel: true,
          pinned: options[:pinned],
          valueGetter: link,
          colId: field,
          cellStyle: { 'padding-left': '0px', 'padding-right': '0px' }, # Remove padding so the button fills the cell, presenting a better target
          cellRenderer: options[:cellRenderer] || default_renderer
        }
      end

      def href_prompt(link, field, options = {})
        href(link, field, options.merge(cellRenderer: 'crossbeamsGridFormatters.hrefPromptFormatter'))
      end

      def col(field, caption = nil, options = {}) # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
        grid_config = OpenStruct.new(hide_for_client: [], tree: false)
        column_definition = ColumnDefinition.new(grid_config)
        col = options.merge(name: field, caption: caption || field.to_s.tr('_', ' ').capitalize)
        hs = column_definition.column_hash(OpenStruct.new(col))

        hs[:cellRenderer] = 'crossbeamsGridFormatters.iconFormatter' if options[:icon]
        hs[:headerTooltip] = options[:tooltip] if options[:tooltip]

        # Rules for editable columns
        if options[:editable]
          hs[:headerClass] = %i[integer number].include?(options[:data_type]) ? 'ag-numeric-header gridEditableColumn' : 'gridEditableColumn'
          hs[:headerTooltip] = "#{hs[:headerTooltip]} (editable)"
          hs[:editable] = true
          if options[:cellEditor]
            hs[:cellEditor] = options[:cellEditor]
            hs[:cellEditor] = 'agRichSelectCellEditor' if %w[select search_select].include?(options[:cellEditor])
            hs[:cellEditor] = 'agLargeTextCellEditor' if options[:cellEditor] == 'textarea'
          elsif %i[integer number].include?(options[:data_type])
            hs[:cellEditor] = 'agNumberCellEditor'
            hs[:cellEditorParams] = if options[:data_type] == :integer
                                      { showStepperButtons: true, precision: 0 }
                                    else
                                      { showStepperButtons: true }
                                    end
          elsif options[:data_type] == :boolean
            hs[:cellEditor] = 'agCheckboxCellEditor'
          elsif options[:data_type] == :date
            hs[:cellEditor] = 'agDateCellEditor'
          elsif options[:data_type] == :datetime
            hs[:cellEditor] = 'agDateCellEditor'
            hs[:cellEditorParams] = { includeTime: true }
          else
            hs[:cellEditor] = 'agTextCellEditor'
          end

          if options[:cellEditorParams]
            if %w[select search_select].include?(options[:cellEditor])
              if options[:cellEditorParams][:lookup_url]
                hs[:cellEditor] = 'searchableSelectCellEditor'
                hs[:cellEditorParams] = { lookupUrl: options[:cellEditorParams][:lookup_url],
                                          selectWidth: options[:cellEditorParams][:width] || 200 }
              else
                hs[:cellEditor] = 'agRichSelectCellEditor'
                values = options[:cellEditorParams][:values]
                hs[:cellEditorParams] = { allowTyping: true,
                                          filterList: true,
                                          highlightMatch: true,
                                          searchType: 'matchAny',
                                          valueListMaxHeight: 220 }
                hs[:cellEditorParams][:valueListMaxWidth] = options[:cellEditorParams][:width] if options[:cellEditorParams][:width]
                if values.first.is_a?(Array) # 2D array of options
                  values = select_editor_values_for_2d(values)
                  hs[:cellEditorParams][:values] = values
                  hs[:cellEditorParams][:format2D] = true
                else
                  hs[:cellEditorParams][:values] = values.map { |a| a.nil? ? '' : a }
                end
              end
            else
              hs[:cellEditorParams] = options[:cellEditorParams]
            end
          end
        end

        # Outdated (nested grids)
        # if options[:expands_nested_grid] && options[:expands_nested_grid] == field.to_s
        #   hs[:cellRenderer]       = 'group' # This column will have the expand/contract controls.
        #   hs[:cellRendererParams] = { suppressCount: true } # There is always one child (a sub-grid), so hide the count.
        #   hs.delete(:enableRowGroup) # ... see if this helps?????
        #   hs.delete(:enablePivot) # ... see if this helps?????
        # end
        @columns << hs
      end

      def integer(field, caption = nil, options = {})
        hard_opts = { data_type: :integer }
        all_opts = options.merge(hard_opts)
        col(field, caption, all_opts)
      end

      def numeric(field, caption = nil, options = {})
        soft_opts = { format: :delimited_1000 } # rubocop:disable Naming/VariableNumber
        hard_opts = { data_type: :number }
        all_opts = soft_opts.merge(options).merge(hard_opts)
        col(field, caption, all_opts)
      end

      def boolean(field, caption = nil, options = {})
        hard_opts = { data_type: :boolean }
        all_opts = options.merge(hard_opts)
        col(field, caption, all_opts)
      end

      def icon(field, caption = nil, options = {})
        hard_opts = { icon: true }
        all_opts = options.merge(hard_opts)
        col(field, caption, all_opts)
      end

      private

      def select_editor_values_for_2d(values)
        values.map { |f, l| { name: f.nil? || f.empty? ? ' ' : f, code: l || 'C' } }
      end
    end
  end
end
