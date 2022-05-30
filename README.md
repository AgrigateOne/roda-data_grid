# Roda::DataGrid

A Roda plugin for rendering data grids using crossbeams-dataminer and crossbeams-layout.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'roda-data_grid'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install roda-data_grid

## Usage

### Configure the plugin

In the Roda app configure the plugin:

```ruby
  plugin :data_grid, path: File.dirname(__FILE__),
                     list_url: '/list/%s/grid',
                     search_url: '/search/%s/grid',
                     filter_url: '/search/%s',
                     run_search_url: '/search/%s/run',
                     run_to_excel_url: '/search/%s/xls'
```

YAML files defining dataminer queries must be stored in `grid_definitions/dataminer_queries` relative to the `path` option.
List definition files and search definition files must be in the relevant directories as shown here:

    ├── grid_definitions
    │   ├── dataminer_queries
    │   ├── lists
    │   ├── lookups
    │   └── searches

The various paths for lists and searches must include `%s` where the list or search filename will be substituted.

### Set up routes

```ruby
    # Generic grid lists.
    r.on 'list' do
      r.on :id do |id|
        r.is do
          show_page { render_data_grid_page(id) }
        end

        r.on 'grid' do
          response['Content-Type'] = 'application/json'
          render_data_grid_rows(id)
        end
      end
    end

    # Generic code for grid searches.
    r.on 'search' do
      r.on :id do |id|
        r.is do
          render_search_filter(id, params)
        end

        r.on 'run' do
          show_page { render_search_grid_page(id, params) }
        end

        r.on 'grid' do
          response['Content-Type'] = 'application/json'
          render_search_grid_rows(id,
                                  params,
                                  ->(args) { Crossbeams::Config::ClientRuleChecker.rule_passed?(*args) },
                                  ->(function, program, permission) { auth_blocked?(function, program.split(','), permission) },
                                  ->(args) { Crossbeams::Config::UserPermissions.can_user?(current_user, *args) })
        end

        r.on 'xls' do
          'Write code here to export to Excel'
        end
      end
    end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/roda-data_grid.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

