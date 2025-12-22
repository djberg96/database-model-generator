## 0.7.0 - 22-Dec-2025
* Added full PostgreSQL support via the pg gem.
* Created PostgreSQL generator implementation with all features.
* Added PostgreSQL Docker setup for testing.
* Added comprehensive PostgreSQL test suite.
* Updated documentation to include PostgreSQL examples.
* Added pg gem as development dependency.

## 0.6.1 - 28-Jul-2025
* Added "datetime" field for validates_timeliness.
* Added validates_timeliness as a development dependency.

## 0.6.0 - 24-Jul-2025
* Renamed from oracle-model-generator to database-model-generator.
* Added enum support.
* Added polymorphic association support.

## 0.5.0 - 22-Jul-2025
* Added docker related files, so you can now fire up an Oracle container and
  run the specs against that.
* Replaced test-unit with rspec.
* Changed the license to Apache-2.0.

## 0.4.1 - 1-Feb-2016
* This gem is now signed.
* Updated the gem related tasks in the Rakefile.
* Added an oracle-model-generator.rb file for convenience.

## 0.4.0 - 7-Nov-2014
* Added support for minitest test file output.

## 0.3.2 - 6-Nov-2014
* Removed explicit references to Rails 3 in documentation. It's now simply
  Rails 2, or Rails 3 or higher.
* Some minor updates in generated test file text, as test-unit 2 no longer
  requires the require workaround.
* Updates to Rakefile and gemspec.

## 0.3.1 - 3-Apr-2012
* Added the --class option that allows you to specify the model name on the
  command line. Thanks go to Daniel Luna for the patch (plus some minor fixes).

## 0.3.0 - 12-May-2011
* Added automatic test generation. In addition to the active record model file,
  a test file will be generated that includes a series of stock tests that
  are based on the model's validations. At the moment only test-unit is
  supported, but I'll eventually add rspec.
* Added the -x/--tests command line option for the new test generation feature.
* The dependencies method now returns an array of dependencies for the given
  table or view.
* The table method has been altered. It now returns just the plain, uppercased
  name of the table. A new method called 'model' now returns the active record
  model name.
* The default output file name will now chop any trailing 's' characters.
* More tests and comments added.

## 0.2.1 - 3-May-2011
* Fixed a bug where the omg binary blew up if you didn't have the dbi-dbrc
  library installed. It's supposed to be optional. Thanks go to Jason Roth
  for the spot.

## 0.2.0 - 8-Mar-2011
* Added the -r/--rails command line option. By default the omg binary will
  now generate Rails 3 style validations. If you want Rails 2 validations,
  specify "-r 2" on the command line.
* The numericality validations are now more strict, and will match the
  scale and precision exactly as defined instead of rounding to the nearest
  whole number, for Rails 3 anyway.

## 0.1.0 - 6-Oct-2010
* Initial release.
