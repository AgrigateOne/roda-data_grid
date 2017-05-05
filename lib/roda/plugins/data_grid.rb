# require 'roda/data_grid/list_renderer'

class Roda
  module RodaPlugins
    module DataGrid

      def self.configure(app, opts = {})
        app.opts[:data_grid] = opts.dup

        opts = app.opts[:data_grid]
        # opts[:renderer] ||= ::Roda::WillPaginate::LinkRenderer
        #
        # if opts[:renderer].is_a?(Symbol)
        #   c_name = "Roda::WillPaginate::#{opts[:renderer].to_s.capitalize}PaginationRenderer"
        #   opts[:renderer] = const_get(c_name)
        # end
      end

      module InstanceMethods
        # include ::WillPaginate::ViewHelpers
        #
        # def will_paginate(collection, options = {}) #:nodoc:
        #   super(collection, opts[:will_paginate].merge(options))
        # end
        def render_list_page
          "RENDER LIST: #{opts[:data_grid][:path]}"
        end
        def render_list_grid
          "RENDER LIST GRID: #{opts[:data_grid][:path]}"
        end
      end
    end

    register_plugin(:data_grid, DataGrid)
  end
end
