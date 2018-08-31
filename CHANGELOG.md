# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres roughly to [Semantic Versioning](http://semver.org/).


## [Unreleased]
### Added
### Changed
### Fixed

## [0.1.8] - 2018-08-31
### Added
- Grid can render as a tree.
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
