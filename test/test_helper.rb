$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'roda/data_grid'

require 'minitest/autorun'

# Simple override for Postgres DB connection constant.
class PgDb
  def array_expect(args)
    if args.is_a?(Array)
      @array_rule = ->(inp) { args }
    elsif args == :get_bool
      @array_rule = ->(inp) do
        s = Struct.new(:get)
        inp.include?('true') ? s.new(true) : s.new(false)
      end
    else
      @array_rule = ->(inp) { [] }
    end
  end

  def array_resolve(arg)
    @array_rule.call(arg)
  end

  def [](arg)
    # obj that implements to_a and map - with useful data
    # BASIC_DATA
    array_resolve(arg)
  end
end
DB = PgDb.new
