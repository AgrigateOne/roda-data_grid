# frozen_string_literal: true

module Crossbeams
  module DataGrid
    # Shared tasks for building up column definitions for grids
    module GridColdefBuilder
      def column_definitions(options = {}) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        col_defs = []
        edit_columns = if config.edit_rules
                         (config.edit_rules[:editable_fields] || {}).keys
                       else
                         []
                       end
        # Actions
        if config.actions
          this_col = make_subitems(config.actions)
          # TODO: make use of column context to add custom properties
          hs = { headerName: '', pinned: 'left',
                 width: 60,
                 suppressHeaderMenuButton: true,   sortable: false,   suppressMovable: true,
                 filter: false,
                 enableValue: false,   suppressColumnsToolPanel: true,
                 suppressFiltersToolPanel: true,
                 valueGetter: this_col.to_json.to_s,
                 context: { suppressCsvExport: true },
                 colId: 'action_links',
                 cellStyle: { 'padding-left': '0px', 'padding-right': '0px' }, # Remove padding so the button fills the cell, presenting a better target
                 cellRenderer: 'crossbeamsGridFormatters.menuActionsRenderer' }
          hs[:enableRowGroup] = false unless config.tree
          hs[:enablePivot] = false unless config.tree
          col_defs << hs
        end

        column_definition = ColumnDefinition.new(config)

        (options[:column_set] || report.ordered_columns).each do |col|
          hs = column_definition.column_hash(col)

          # Rules for editable columns
          if edit_columns.include?(col.name)
            hs[:editable] = true
            hs[:headerClass] = hs[:type] && hs[:type] == 'numericColumn' ? 'ag-numeric-header gridEditableColumn' : 'gridEditableColumn'
            hs[:headerTooltip] = "#{hs[:headerTooltip]} (editable)"

            rule = config.edit_rules[:editable_fields][col.name]
            if rule && rule[:editor]
              if rule[:editor] == :numeric
                hs[:cellEditor] = 'agNumberCellEditor'
                hs[:cellEditorParams] = if col.data_type == :integer
                                          { showStepperButtons: true, precision: 0 }
                                        else
                                          { showStepperButtons: true }
                                        end
              end
              hs[:cellEditor] = 'agLargeTextCellEditor' if rule[:editor] == :textarea

              if %i[search_select select].include?(rule[:editor])
                hs[:cellEditor] = 'agRichSelectCellEditor'
                if rule[:lookup_url]
                  hs[:cellEditor] = 'searchableSelectCellEditor'
                  hs[:cellEditorParams] = { lookupUrl: rule[:lookup_url], selectWidth: rule[:width] || 200 }
                else
                  values = select_editor_values(rule)
                  hs[:cellEditorParams] = { values: values,
                                            allowTyping: true,
                                            filterList: true,
                                            highlightMatch: true,
                                            searchType: 'matchAny',
                                            valueListMaxHeight: 220 }
                  if values.first.is_a?(Array) # 2D array of options
                    values = select_editor_values_for_2d(values)
                    hs[:cellEditorParams][:values] = values
                    hs[:cellEditorParams][:format2D] = true
                  else
                    hs[:cellEditorParams][:values] = values.map { |a| a.nil? ? '' : a }
                  end
                  hs[:cellEditorParams][:valueListMaxWidth] = rule[:width] if rule[:width]
                end
              end
            elsif col.data_type == :boolean
              hs[:cellEditor] = 'agCheckboxCellEditor'
            elsif col.data_type == :date
              hs[:cellEditor] = 'agDateCellEditor'
            elsif col.data_type == :datetime
              hs[:cellEditor] = 'agDateCellEditor'
              hs[:cellEditorParams] = { includeTime: true }
            else
              hs[:cellEditor] = 'agTextCellEditor'
            end
          end

          # Outdated (nested grids)
          # if options[:expands_nested_grid] && options[:expands_nested_grid] == col.name
          #   hs[:cellRenderer]       = 'group' # This column will have the expand/contract controls.
          #   hs[:cellRendererParams] = { suppressCount: true } # There is always one child (a sub-grid), so hide the count.
          #   hs.delete(:enableRowGroup) # ... see if this helps?????
          #   hs.delete(:enablePivot) # ... see if this helps?????
          # end

          # hs[:cellClassRules] = { "grid-row-red": "x === 'Fred'" } if col.name == 'author'
          col_defs << hs
        end

        (config.calculated_columns || []).each do |raw|
          pos, hs = column_definition.calculated_column(raw)
          col_defs.insert(pos, hs)
        end
        col_defs
      end

      # Build action column items recursively.
      def make_subitems(actions, level = 0) # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
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

          # Check if user has permission for this action:
          next if action[:has_permission] && !@has_permission.call(action[:has_permission].map(&:to_sym))

          keys = action[:url].split(/\$/).select { |key| key.start_with?(':') }
          url  = action[:url]
          keys.each_with_index { |key, index| url = url.gsub("$#{key}$", "$col#{index}$") }
          link_h = {
            text: action[:text] || 'link',
            url: url
          }
          keys.each_with_index { |key, index| link_h["col#{index}".to_sym] = key.sub(':', '') }
          if action[:is_delete]
            link_h[:prompt] = 'Are you sure?'
            link_h[:method] = 'delete'
          end
          link_h[:method] = 'post' if action[:remote]

          link_h[:icon] = action[:icon] if action[:icon]
          link_h[:prompt] = action[:prompt] if action[:prompt]
          link_h[:title] = action[:title] if action[:title]
          link_h[:title_field] = action[:title_field] if action[:title_field]
          link_h[:popup] = action[:popup] if action[:popup]
          link_h[:loading_window] = action[:loading_window] if action[:loading_window]
          link_h[:hide_if_null] = action[:hide_if_null] if action[:hide_if_null]
          link_h[:hide_if_present] = action[:hide_if_present] if action[:hide_if_present]
          link_h[:hide_if_true] = action[:hide_if_true] if action[:hide_if_true]
          link_h[:hide_if_false] = action[:hide_if_false] if action[:hide_if_false]
          this_col << link_h
        end
        this_col
      end

      def assert_actions_ok! # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
        return unless config.actions

        config.actions.each do |action|
          action.each_key do |key|
            raise ArgumentError, "#{key} is not a valid action attribute" unless %i[
              auth
              has_permission
              hide_if_false
              hide_if_null
              hide_if_present
              hide_if_true
              hide_if_env_var
              show_if_env_var
              hide_for_client_rule
              show_for_client_rule
              icon
              is_delete
              remote
              loading_window
              popup
              prompt
              separator
              submenu
              text
              title
              title_field
              url
            ].include?(key)
          end

          raise ArgumentError, 'A grid action cannot be both a popup and a loading_window' if action[:popup] && action[:loading_window]
          raise ArgumentError, 'A remote grid action must also be defined as a popup' if action[:remote] && !action[:popup]
        end
      end
    end
  end
end
