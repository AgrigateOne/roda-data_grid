# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres roughly to [Semantic Versioning](http://semver.org/).


## [Unreleased]
### Added
- New "any" operator can be used to search where an array column contains a value
### Changed
### Fixed
- Search: parameter filter screen shows the grid caption if provided instead of the report caption
- Grid page controls: cater for controls without URL on pages with querystring (e.g. help button on a page with a limit set)

## [1.5.1] - 2024-05-29
### Added
- Search grids can define `fixed_parameters` which will always be applied to the query
- Search grids can define a `selected_parameter_list` to only show those parameters to the user - even if the report definition has more

## [1.5.0] - 2024-01-03
### Added
- List and lookup grids can have fixed params. These are parameters that are applied in addition to the provided parameters. For example, a multi-tenanted site could use this to ensure a grid is always filtered by an appropriate key

## [1.2.1] - 2023-10-19
### Added
### Changed
- `value_sql` can return two columns - the first is used for display, and the second for the value
### Fixed
- If a column is set to sum when grouped, set its aggFunc so that it will be included automatically if the grid is grouped

## [1.2.0] - 2023-03-20
### Added
- Formatters for sparkline columns - `:sparkline`, `:sparkline_text`, `:sparkarea`, `:sparkarea_text`, `:sparkcol`, `:sparkcol_text`, `:sparkbar`, `:sparkbar_text`
- If a grid action column is defined as a `remote` action, set the action method to `post`
- Remote link for column definer

## [1.1.0] - 2023-01-15
### Added
- Show columns for selected clients only (using `show_for_client` option)
- New column formatter "barColourFormatter". This works for a column containing 0 or more semicolon-separated characters (b, g, o, r, s, y) each will display as a coloured section of a bar (blue, green, orange, red, silver, yellow). This can be used at a high-level to indicate a set of states.

## [1.0.0] - 2022-10-27
### Added
- Page control links can build their caption from SQL using the new `sql_text` attribute which has access to the URL querystring parameters for building conditions.
### Changed
- Upgrade to Ruby 3
- Housekeeping: remove DataminerControl and references to the class

## [0.5.8] - 2022-06-08
### Added
- ColumnDefiner can specify an `icon` column to render as an icon
### Fixed
- LIMIT parameter was ignored.
- To value for between parameters was incorrectly referenced.

## [0.5.7] - 2021-02-29
### Added
- A page control can be hidden when the value of the key parameter in the URL does not matches one of the list of `show_for_key` values in the list definition.
- A new setting for `groupDefaultExpanded` can be used to set the number of initially expanded groups in a grid.
### Changed
- Use library-specific Error class instead of RuntimeError.

## [0.5.6] - 2021-07-03
### Added
- `render_debug_list` method returns debug information for a List grid.
### Changed
- `ColumnDefiner` sets the correct classes in the header to highlight editable columns.

## [0.5.5] - 2021-06-07
### Added
- Column definer: specify `for_multiselect` to get a checkbox column.
- Pass in a proc to check a client rule and show/hide controls if the rule is true.
- Pass in a proc to check a client rule and show/hide menu actions if the rule is true.
### Changed
- Conditions can include an `optional: true` entry. If the value passed-in is nil and optional is set, the condition will be excluded from the WHERE clause.
### Fixed
- Raise an exception for data grids when there is a parse error when applying parameters to a query.

## [0.5.4] - 2021-01-19
### Added
- List grid: searchable select can build items from a lookup URL. Provide `lookup_url: "/path/$:colname$` instead of values for the `cellEditorParams`.
### Changed
- List grid: can include URL parameters in grid caption for conditional grids.

## [0.5.3] - 2020-11-19
### Added
- Lists and Searches can include a `hide_for_client` section to hide grid columns based on the environment variable `CLIENT_CODE`.

## [0.5.2] - 2020-11-13
### Added
- Actions get `hide_if_env_var` and `show_if_env_var` options. The values for these are comma-separated lists of ENV VAR keys and values separated by `:`.

## [0.5.1] - 2020-09-21
### Added
- New grid cell editor: `search_select`. This lists options that can be filtered in the editor.

## [0.5.0] - 2020-09-07
### Changed
- suppressToolPanel changes for AG Grid version 23.2.1.
### Fixed
- Popup link for column definer: fix icon names.
- Convert PG.Hstore columns to string.

## [0.4.1] - 2020-04-22
### Added
- Add special variables for conditions: `START_OF_DAY`, `END_OF_DAY` and `TODAY`.
### Changed
- Use constants for column with defaults and set a narrower default for datatime columns.

## [0.4.0] - 2020-04-03
### Added
- Adding `_limit` or `_offset` parameters will alter the report's limit / offset values.
### Changed
- Move from `axlsx` gem to community-maintained version `caxlsx`.

## [0.3.1] - 2020-03-26
### Added
- `dateTimeWithoutZoneFormatter` for formatting a datetime without time zone, but with seconds.
### Changed
- `dateTimeWithoutSecsOrZoneFormatter` changed from a cellRenderer to a valueFormatter.

## [0.3.0] - 2020-03-12
### Added
- Select editor can receive a width which specifies the pixel width of items in the dropdown. The default is 200.
### Changed
- Lookup grid's POST url can include other parameters, not just "id".
- All datetime columns render using `dateTimeWithoutSecsOrZoneFormatter` which strips seconds and time zone display.

## [0.2.3] - 2019-09-27
### Changed
- `value_sql` for editable columns can include parameters.
- Changed structure for setting captions, a caption can be set per condition key in list yml files.

## [0.2.2] - 2019-08-31
### Added
- If a report definition includes a colour key in its external_settings, pass these values on to the Grid header for display.

## [0.2.1] - 2019-08-27
### Changed
- Changes related to upgrade of AG Grid to version 21.
- Search presenter gets parameters sorted by UI priority.
- Sensible defaults for cell editors (numeric/integer).
- Use agRichSelectCellEditor for select boxes.
- Add an iconFormatter for columns named "icon".

## [0.2.0] - 2019-06-07
### Added
- A list.yml file can optionally point to a different dataminer_definition to run its query.
  This is based on the environment variable "CLIENT_CODE". If the environment variable is set and there is a matching
  entry under `:datamnier_client_definitions`, that query definition will be used.
- An action can be blocked if the user does not have the correct permission. New option for ListGridData - `has_permission` - which is a lambda which gets passed an array of permission tree keys and returns true if the user has permission, or false otherwise.

## [0.1.12] - 2019-03-13
### Added
- Raise an informative error if the parameters include a key that does not exist in the `conditions` section.
- A page control can be hidden when the value of the key parameter in the URL matches one of the list of `hide_for_key` values in the list definition.
- Handle lookup grid definitions.
- Inline editing of grid columns.
### Fixed
- Exception was raised when the params included a key for a multiselect and there were no conditions with the same key. This was because the multiselect key was being used as the conditions key.

## [0.1.11] - 2019-01-08
### Added
- Pass `pinned` attribute to AG Grid if set. It can be 'left' or 'right' or nil.

## [0.1.10] - 2018-11-20
### Added
- Specify calculated columns - calculated on-the-fly by AG Grid.
- Grid action URL can be opened in a loading window. Set `loading_window` to `true`.
### Changed
- Use AG Grid 1.19's own formatting of number columns.
- Raises an exception if any action's key is invalid.

## [0.1.9] - 2018-10-16
### Added
- Chosen parameters can be displayed from a toggle button on the display page.
- Add the grid id to page control buttons.
### Changed
- Check all SQL snippets (get caption, preselect ids, hide button etc.) are SELECTs and raise an exception if they are not.
- Refactor list grid methods out of DataminerControl. New ListGridConfig, ListGridDefinition and ListGridData classes.
- Make checkbox column a bit wider for multiselects.
### Fixed
- Multiselect conditions code had a couple of problems.
- Fix to conditions-handling for listing data.

## [0.1.8] - 2018-08-31
### Added
- Grid can render as a tree.
- Grid action can be `remote` - this will result in a POST fetch request
### Changed
- A page control can be hidden based on the result of running the SQL in `hide_if_sql_returns_true`.

## [0.1.7] - 2018-08-10
### Changed
- All icon usage changed from using FontAwesome to using embedded SVG icons.

## [0.1.6] - 2018-07-06
### Changed
- `multiselect_save_remote` renamed to `multiselect_save_method` and changed from a boolean to a string which can be 'http' (default), 'remote' or 'dialog'. `http` will post selected ids. `remote` will post selected ids using a `fetch` request. `dialog` will bring up a dialog and send a GET request with the selected ids to render in the dialog.
### Fixed
- Make fit-height optional. Grids do not render well inside modal dialog when fit-height is set.
- Conditions for multiselects were not working properly.

## [0.1.5] - 2018-06-29
### Changed
- Enhanced the styling of the "Back" button.
- Make list and search grids fit the available height.
### Fixed
- Formatters for numeric columns use valueFormatter instead of cellRenderer. This allows aggregates to work properly.

## [0.1.4] - 2018-06-19
### Added
- Crossbeams::DataGrid::ColumnDefiner provides a DSL interface for creating column definitions for data grids.

## [0.1.3] - 2018-05-03
### Changed
- The deny authorization call requires a third parameter [functional area name]. This is a backwards-incompatible change.

## [0.1.2] - 2018-02-20
### Added
- This changelog.
### Changed
- The helper that builds JSON query params can now receive a database connection.

## [0.1.1] - 2018-02-08
### Changed
- Upgrade to Ruby 2.5.
- Start to use git flow for releases.
