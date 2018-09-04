# frozen_string_literal: true

class Roda
  module DataGrid
    module DataGridHelpers
      # Make option tags for a select tag.
      #
      # @param items [Array] the option items.
      # @return [String] the HTML +option+ tags.
      def make_options(items)
        items.map do |item|
          if item.is_a?(Array)
            "<option value=\"#{item.last}\">#{item.first}</option>"
          else
            "<option value=\"#{item}\">#{item}</option>"
          end
        end.join("\n")
      end

      # Take a report's query parameter definitions and create a JSON representation of them.
      #
      # @param query_params [Array<Crossbeams::Dataminer::QueryParameterDefinition>] the parameter definitions.
      # @return [JSON] a hash of config for the parameters defined for a report.
      def make_query_param_json(query_params, connection = DB)
        common_ops = [
          ['is', '='],
          ['is not', '<>'],
          ['greater than', '>'],
          ['less than', '<'],
          ['greater than or equal to', '>='],
          ['less than or equal to', '<='],
          ['is blank', 'is_null'],
          ['is NOT blank', 'not_null']
        ]
        text_ops = [
          [['starts with'], ['starts_with']],
          [['ends with'], ['ends_with']],
          %w[contains contains]
        ]
        date_ops = [
          %w[between between]
        ]
        # ar = []
        qp_hash = {}
        query_params.each do |query_param|
          hs = { column: query_param.column, caption: query_param.caption,
                 default_value: query_param.default_value, data_type: query_param.data_type,
                 control_type: query_param.control_type }
          if query_param.control_type == :list
            hs[:operator] = common_ops
            hs[:list_values] = if query_param.includes_list_options?
                                 query_param.build_list.list_values
                               else
                                 query_param.build_list do |sql|
                                   raise "SQL for #{param list} is not a SELECT" if sql.match?(/insert |update |delete /i)
                                   connection[sql].map(&:values)
                                 end.list_values
                               end
            # if query_param.includes_list_options?
            #   hs[:list_values] = query_param.build_list.list_values
            # else
            # TODO: find a way to run SQL.
            # hs[:list_values] = query_param.build_list { |sql| Crossbeams::DataminerPortal::DB[sql].all.map {|r| r.values } }.list_values
            #### this_db = Sequel.connect('postgres://postgres:postgres@localhost:5432/bookshelf_development')
            # hs[:list_values] = query_param.build_list {|sql| BookRepository.new.raw_query(sql).map {|r| r.values } }.list_values
            ### hs[:list_values] = query_param.build_list {|sql| this_db[sql].map {|r| r.values } }.list_values
            # hs[:list_values] = query_param.build_list { |sql| DB[sql].map(&:values) }.list_values
            # This needs to use repository...
            # end
          elsif query_param.control_type == :daterange
            hs[:operator] = date_ops + common_ops
          else
            hs[:operator] = common_ops + text_ops
          end
          # ar << hs
          qp_hash[query_param.column] = hs
        end
        # ar.to_json
        qp_hash.to_json
      end
    end
  end
end
