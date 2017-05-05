# require 'roda/data_grid/list_renderer'

class Roda
  module RodaPlugins
    module DataGrid
      def self.configure(app, opts = {})
        app.opts[:data_grid] = opts.dup
      end

      module InstanceMethods
        def render_data_grid_page(id)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], list_file: id)

          layout = Crossbeams::Layout::Page.new form_object: dmc.report
          layout.build do |page, page_config|
            page.add_grid('grd1', opts[:data_grid][:list_url].sub('{id}', id),
                          caption: page_config.form_object.caption)
          end
          layout
        end

        def render_data_grid_rows(id)
          dmc = DataminerControl.new(path: opts[:data_grid][:path], list_file: id)
          dmc.list_rows(params)
        end
      end
    end

    register_plugin(:data_grid, DataGrid)
  end
end
