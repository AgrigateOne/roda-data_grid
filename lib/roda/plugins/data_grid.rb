require 'roda/data_grid/dataminer_control'
require 'roda/data_grid/data_grid_helpers'

class Roda
  module RodaPlugins
    module DataGrid
      def self.configure(app, opts = {})
        app.opts[:data_grid] = opts.dup
      end

      module InstanceMethods
        include Roda::DataGrid::DataGridHelpers

        def render_data_grid_page(id)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], list_file: id)
          grid_path = dmc.is_nested_grid? ? opts[:data_grid][:list_nested_url] : opts[:data_grid][:list_url]

          layout = Crossbeams::Layout::Page.new form_object: dmc.report
          layout.build do |page, page_config|
            page.add_grid("grid_#{id}", grid_path.%(id),
                          caption: page_config.form_object.caption, is_nested: dmc.is_nested_grid?)
          end
          layout
        end

        def render_data_grid_rows(id)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], list_file: id)
          dmc.list_rows
        end

        def render_data_grid_nested_rows(id)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], list_file: id)
          dmc.list_nested_rows
        end

        def render_search_filter(id, params)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], search_file: id)
          presenter = OpenStruct.new(rpt: dmc.report,
                                     qps: dmc.report.query_parameter_definitions,
                                     rpt_id: id,
                                     load_params: (params[:back] && params[:back] == 'y'))
          fp = File.expand_path('../../data_grid/search_filter.erb', __FILE__)
          view(path: fp,
               locals: { presenter: presenter,
                         run_search_url: opts[:data_grid][:run_search_url] % id,
                         run_to_excel_url: opts[:data_grid][:run_to_excel_url] % id })
        end

        def render_search_grid_page(id, params)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], search_file: id)
          dmc.apply_params(params)

          layout = Crossbeams::Layout::Page.new form_object: dmc.report
          layout.build do |page, page_config|
            page.row do |row|
              row.column do |col|
                col.add_text "<a href='#{opts[:data_grid][:filter_url].%(id)}?back=y'>Back</a>"
              end
            end
            page.add_grid("search_grid_#{id}", "#{opts[:data_grid][:search_url].%(id)}?json_var=#{CGI.escape(params[:json_var])}" \
                                  "&limit=#{params[:limit]}&offset=#{params[:offset]}",
                          caption: page_config.form_object.caption)
          end
          layout
        end

        def render_search_grid_rows(id, params)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], search_file: id)
          dmc.search_rows(params)
        end

        def render_excel_rows(id, params)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], search_file: id)
          [dmc.report.caption, dmc.excel_rows(params)]
        end
      end
    end

    register_plugin(:data_grid, DataGrid)
  end
end
