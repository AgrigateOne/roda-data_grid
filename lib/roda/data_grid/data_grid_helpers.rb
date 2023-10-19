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

      COMMON_OPS = [
        ['is', '='],
        ['is not', '<>'],
        ['greater than', '>'],
        ['less than', '<'],
        ['greater than or equal to', '>='],
        ['less than or equal to', '<='],
        ['is blank', 'is_null'],
        ['is NOT blank', 'not_null']
      ].freeze
      TEXT_OPS = [
        ['starts with', 'starts_with'],
        ['ends with', 'ends_with'],
        %w[contains contains]
      ].freeze
      DATE_OPS = [
        %w[between between]
      ].freeze

      # Apply lookup list options to a query param.
      #
      # @param query_param [Crossbeams::Dataminer::QueryParam] the param.
      # @param connection [Sequel::Database] the db connection.
      # @return [Array] list of value for the parameter.
      def build_list_values(query_param, connection)
        if query_param.includes_list_options?
          query_param.build_list.list_values
        else
          query_param.build_list do |sql|
            raise "SQL for #{query_param.column} is not set" if sql.nil?
            raise "SQL for #{query_param.column} is not a SELECT" if sql.match?(/insert |update |delete /i)

            connection[sql].map(&:values)
          end.list_values
        end
      end

      # Assemble appropriate operators for a control type.
      #
      # @param control_type [Symbol] the type.
      # @return [Array] a list of text/value array pairs.
      def build_operators(control_type)
        case control_type
        when :list
          COMMON_OPS
        when :daterange
          DATE_OPS + COMMON_OPS
        else
          COMMON_OPS + TEXT_OPS
        end
      end

      # Take a report's query parameter definitions and create a JSON representation of them.
      #
      # @param query_params [Array<Crossbeams::Dataminer::QueryParameterDefinition>] the parameter definitions.
      # @return [JSON] a hash of config for the parameters defined for a report.
      def make_query_param_json(query_params, connection = DB)
        qp_hash = {}
        query_params.each do |query_param|
          hs = { column: query_param.column, caption: query_param.caption,
                 default_value: query_param.default_value, data_type: query_param.data_type,
                 control_type: query_param.control_type }
          hs[:list_values] = build_list_values(query_param, connection) if query_param.control_type == :list
          hs[:operator] = build_operators(query_param.control_type)
          qp_hash[query_param.column] = hs
        end
        qp_hash.to_json
      end
    end
  end
end
