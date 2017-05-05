class Roda
  module DataGrid
    module DataGridHelpers
      def make_options(ar)
        ar.map do |a|
          if a.kind_of?(Array)
            "<option value=\"#{a.last}\">#{a.first}</option>"
          else
            "<option value=\"#{a}\">#{a}</option>"
          end
        end.join("\n")
      end

      def make_query_param_json(query_params)
        common_ops = [
          ['is', "="],
          ['is not', "<>"],
          ['greater than', ">"],
          ['less than', "<"],
          ['greater than or equal to', ">="],
          ['less than or equal to', "<="],
          ['is blank', "is_null"],
          ['is NOT blank', "not_null"]
        ]
        text_ops = [
          ['starts with', "starts_with"],
          ['ends with', "ends_with"],
          ['contains', "contains"]
        ]
        date_ops = [
          ['between', "between"]
        ]
        # ar = []
        qp_hash = {}
        query_params.each do |query_param|
          hs = {column: query_param.column, caption: query_param.caption,
                default_value: query_param.default_value, data_type: query_param.data_type,
                control_type: query_param.control_type}
          if query_param.control_type == :list
            hs[:operator] = common_ops
            if query_param.includes_list_options?
              hs[:list_values] = query_param.build_list.list_values
            else
    # TODO: find a way to run SQL.
              # hs[:list_values] = query_param.build_list {|sql| Crossbeams::DataminerPortal::DB[sql].all.map {|r| r.values } }.list_values
      ####this_db = Sequel.connect('postgres://postgres:postgres@localhost:5432/bookshelf_development')
              # hs[:list_values] = query_param.build_list {|sql| BookRepository.new.raw_query(sql).map {|r| r.values } }.list_values
              ###hs[:list_values] = query_param.build_list {|sql| this_db[sql].map {|r| r.values } }.list_values
              hs[:list_values] = query_param.build_list {|sql| DB.base[sql].map {|r| r.values } }.list_values
              # This needs to use repository...
            end
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
