# frozen_string_literal: true

require 'axlsx'
require 'roda/data_grid/data_grid_helpers'

class Roda
  module RodaPlugins
    module DataGrid
      class Error < StandardError; end

      def self.configure(app, opts = {})
        app.opts[:data_grid] = opts.dup
      end

      module InstanceMethods
        include Roda::DataGrid::DataGridHelpers

        # Helper methods for accessing opts[:data_grid] options
        %i[path search_url filter_url run_search_url run_to_excel_url].each do |opt|
          define_method "opt_#{opt}" do
            opts[:data_grid][opt]
          end
        end

        # Modify the url by applying querystring parameters.
        def configure_page_control(page_control_def, params) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity , Metrics/PerceivedComplexity
          return page_control_def if params.nil? || params[:query_string].nil?

          url = page_control_def[:url]
          return page_control_def if url.nil?

          qs_params = Rack::Utils.parse_nested_query(params[:query_string])
          qs_params.each { |k, v| url.gsub!("$:#{k}$", v) }
          if page_control_def[:sql_text]
            sql_text = page_control_def[:sql_text].dup
            qs_params.each { |k, v| sql_text.gsub!("$:#{k}$", v) } if sql_text
            page_control_def[:text] = DB[sql_text].get if sql_text
          end
          page_control_def
        end

        def render_data_grid_page(id, params = nil) # rubocop:disable Metrics/AbcSize
          grid_def = Crossbeams::DataGrid::ListGridDefinition.new(root_path: opt_path,
                                                                  grid_opts: opts[:data_grid],
                                                                  id: id,
                                                                  params: params)

          layout = Crossbeams::Layout::Page.new form_object: grid_def.report
          layout.build do |page, _|
            page.section do |section|
              grid_def.page_controls.each do |page_control_def|
                section.add_control(configure_page_control(page_control_def.merge(grid_id: "grid_#{id}"), params))
              end
            end
            page.section do |section|
              section.fit_height! if grid_def.fit_height
              section.add_grid("grid_#{id}", grid_def.grid_path, grid_def.render_options)
            end
          end
          layout
        end

        def render_data_grid_page_multiselect(id, params) # rubocop:disable Metrics/AbcSize
          grid_def = Crossbeams::DataGrid::ListGridDefinition.new(root_path: opt_path,
                                                                  grid_opts: opts[:data_grid],
                                                                  multi_key: params[:key],
                                                                  id: id,
                                                                  params: params)

          layout = Crossbeams::Layout::Page.new form_object: grid_def.report
          layout.build do |page, _|
            page.section do |section|
              grid_def.page_controls.each do |page_control_def|
                section.add_control(configure_page_control(page_control_def.merge(grid_id: "grid_#{id}"), params))
              end
            end
            page.section do |section|
              section.fit_height! if grid_def.fit_height
              section.caption = grid_def.multi_grid_caption
              section.hide_caption = grid_def.multi_grid_caption.nil?
              section.add_grid("grid_#{id}", grid_def.grid_path, grid_def.render_options)
            end
          end
          layout
        end

        def render_data_grid_page_lookup(id, key, params) # rubocop:disable Metrics/AbcSize
          grid_def = Crossbeams::DataGrid::LookupGridDefinition.new(root_path: opt_path,
                                                                    grid_opts: opts[:data_grid],
                                                                    lookup_key: key,
                                                                    id: id,
                                                                    params: params)

          layout = Crossbeams::Layout::Page.new form_object: grid_def.report
          layout.build do |page, _|
            page.section do |section|
              section.fit_height! if grid_def.fit_height
              section.caption = grid_def.lookup_grid_caption
              section.hide_caption = grid_def.lookup_grid_caption.nil?
              section.add_grid("grid_#{id}", grid_def.grid_path, grid_def.render_options)
            end
          end
          layout
        end

        def render_data_grid_rows(id, fixed_params: {}, deny_access: nil, has_permission: nil, client_rule_check: nil, params: nil)
          data = Crossbeams::DataGrid::ListGridData.new(id: id,
                                                        root_path: opt_path,
                                                        deny_access: deny_access,
                                                        has_permission: has_permission,
                                                        client_rule_check: client_rule_check,
                                                        fixed_params: fixed_params,
                                                        params: params)
          data.list_rows
        end

        def render_data_grid_multiselect_rows(id, fixed_params, deny_access, has_permission, client_rule_check, multi_key, params)
          data = Crossbeams::DataGrid::ListGridData.new(id: id,
                                                        root_path: opt_path,
                                                        deny_access: deny_access,
                                                        has_permission: has_permission,
                                                        client_rule_check: client_rule_check,
                                                        fixed_params: fixed_params,
                                                        params: params,
                                                        multi_key: multi_key)
          data.list_rows
        end

        def render_data_grid_lookup_rows(id, fixed_params, deny_access, has_permission, client_rule_check, lookup_key, params)
          data = Crossbeams::DataGrid::LookupGridData.new(id: id,
                                                          root_path: opt_path,
                                                          deny_access: deny_access,
                                                          has_permission: has_permission,
                                                          client_rule_check: client_rule_check,
                                                          fixed_params: fixed_params,
                                                          params: params,
                                                          lookup_key: lookup_key)
          data.list_rows
        end

        def render_debug_list(options)
          data = Crossbeams::DataGrid::ListGridData.new(options.merge(root_path: opt_path))
          data.debug_grid
        end

        def render_data_grid_nested_rows(id)
          data = Crossbeams::DataGrid::ListGridData.new(id: id, root_path: opt_path)
          data.list_nested_rows
        end

        def search_view_file(for_rerun)
          if for_rerun
            File.expand_path('../data_grid/search_rerun.erb', __dir__)
          else
            File.expand_path('../data_grid/search_filter.erb', __dir__)
          end
        end

        def search_presenter(id, dmc, params, for_rerun)
          OpenStruct.new(rpt: dmc.report,
                         qps: dmc.parameter_list,
                         caption: dmc.render_options[:caption],
                         rpt_id: id,
                         load_params: (params[:back] && params[:back] == 'y'),
                         rerun: for_rerun)
        end

        def render_search_filter(id, params)
          grid_def = Crossbeams::DataGrid::SearchGridDefinition.new(root_path: opt_path,
                                                                    grid_opts: opts[:data_grid],
                                                                    id: id,
                                                                    params: params)
          for_rerun = params[:rerun] && params[:rerun] == 'y'
          presenter = search_presenter(id, grid_def, params, for_rerun)
          fp = search_view_file(for_rerun)
          view(path: fp,
               locals: { presenter: presenter,
                         run_search_url: opt_run_search_url % id,
                         run_to_excel_url: opt_run_to_excel_url % id })
        end

        def render_search_grid_page(id, params) # rubocop:disable Metrics/AbcSize
          grid_def = Crossbeams::DataGrid::SearchGridDefinition.new(root_path: opt_path,
                                                                    grid_opts: opts[:data_grid],
                                                                    id: id,
                                                                    params: params)

          layout = Crossbeams::Layout::Page.new form_object: grid_def.report
          layout.build do |page, _|
            page.row do |row|
              row.column do |col|
                col.add_control control_type: :link, text: 'Back', url: "#{opt_filter_url.%(id)}?back=y", style: :back_button
                col.add_text %(<div id="rpt_param_text" data-report-param-display="#{id}" hidden></div>),
                             toggle_button: true,
                             toggle_element_id: 'rpt_param_text',
                             toggle_caption: 'Chosen parameters'
              end
            end
            page.section do |section|
              section.fit_height! if grid_def.fit_height
              section.add_grid("search_grid_#{id}", grid_def.grid_path, grid_def.render_options)
            end
          end
          layout
        end

        def render_search_grid_rows(id, params, client_rule_check = nil, deny_access = nil, has_permission = nil)
          always_pass = ->(_) { true }
          data = Crossbeams::DataGrid::SearchGridData.new(id: id,
                                                          root_path: opt_path,
                                                          deny_access: deny_access || always_pass,
                                                          has_permission: has_permission || always_pass,
                                                          client_rule_check: client_rule_check,
                                                          params: params)
          data.list_rows
        end

        def render_excel_rows(id, params)
          always_pass = ->(_) { true }
          data = Crossbeams::DataGrid::SearchGridData.new(id: id,
                                                          root_path: opt_path,
                                                          deny_access: always_pass,
                                                          has_permission: always_pass,
                                                          client_rule_check: always_pass,
                                                          params: params)
          data.list_rows
          [data.report.caption, data.excel_rows]
        end
      end
    end

    register_plugin(:data_grid, DataGrid)
  end
end
