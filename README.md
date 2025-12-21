## Description
A library for generating an ActiveRecord model from an existing database table.

Currently supports Oracle, SQL Server, and PostgreSQL databases.

This will install a "dmg" (Database Model Generator) executable that you can
use from the command line.

## Renamed
Originally called "oracle-model-generator" and put into the dust bin, I've
decided to revive this library with the help of AI. Specifically, I've added
SQLServer and PostgreSQL support, and plan to add more features.

I also plan on lots of improvements, and some general refactoring.

## Synopsis
Using the command line tool:

### Oracle:
`dmg -T oracle -d your_database -t locations -u some_user -p some_password`

### SQL Server:
`dmg -T sqlserver -s localhost -d your_database -t locations -u sa -p your_password`

### PostgreSQL:
`dmg -T postgresql -h localhost -d your_database -t locations -u postgres -p your_password`

### Auto-detection:
# Oracle (default)
`dmg -d your_database -t locations -u some_user -p some_password`

# SQL Server (detected)
`dmg -s localhost -d your_database -t locations -u sa -p password`

The above command results in a file called "location.rb". This is an
ActiveRecord model declaration, with all validations, primary keys,
table name and belongs_to relationships defined.

If your LOCATIONS table looks like this:

```sql
create table locations(
  location_id number(4,0) primary key,
  street_address varchar2(40),
  postal_code varchar2(12),
  city varchar2(30) not null
  state_province varchar2(25),
  country_id CHAR(2),
  constraint "LOC_C_ID_FK" FOREIGN KEY (country_id)
    references COUNTRIES (country_id)
)
```

The dmg library will generate this:

```ruby
class Location < ActiveRecord::Base
  set_table_name :locations
  set_primary_key :location_id

  # Table relationships

  belongs_to :countries

  # Validations

  validates :location_id, :presence => true, :numericality => {
    :less_than_or_equal_to => 9999,
    :greater_than_or_equal_to => -9999,
    :only_integer => true
  }

  validates :street_address, :length => {:maximum => 40}
  validates :postal_code, :length => {:maximum => 12}
  validates :city, :length => {:maximum => 30}, :presence => true
  validates :state_province, :length => {:maximum => 25}
  validates :country_id, :length => {:maximum => 2}
end
```

It will also generate a corresponding test file using test-unit 2 by default.
For the above example you will see some tests like this:

```ruby
class TC_Location < Test::Unit::TestCase
  def setup
    @location = Location.new
  end

  test 'table name is locations' do
    assert_equal('locations', Location.table_name)
  end

  test 'primary key is location_id' do
    assert_equal('location_id', Location.primary_key)
  end

  test 'location_id basic functionality' do
    assert_respond_to(@location, :location_id)
    assert_nothing_raised{ @location.location_id }
    assert_kind_of(Numeric, @location.location_id)
  end

  test 'location_id must be a number' do
    @location.location_id = 'test_string'
    assert_false(@location.valid?)
    assert_true(@location.errors[:location_id].include?('is not a number'))
  end

  test 'location_id cannot exceed the value 9999' do
    @location.location_id = 10000
    assert_false(@location.valid?)
    assert_true(@location.errors[:location_id].include?('must be less than or equal to 9999'))
  end

  # ... and so on.
end
```

## Requirements
* getopt
* One of the following gems, depending on which vendor you're using.

### Oracle
* ruby-oci8

### SQLServer
* tiny_tds

### PostgreSQL
* pg

## Running the specs
### Oracle:
Run `cd docker/oracle && docker-compose run --rm oracle-model-generator bundle exec rspec`.

You may need to use sudo. No guarantees on MacOS because of known issues
with database client libraries.

### SQL Server:
Run `cd docker/sqlserver && ./test.sh` to start SQL Server, then run tests.

### PostgreSQL:
Run `cd docker/postgresql && docker-compose up -d postgres-db` to start PostgreSQL,
then run `docker-compose run --rm dmg_test` to execute tests.

Again, no guarantees on MacOS.

## Optional Libraries
If you want to be able to avoid specifying a username and password on the
command line then you will need the `dbi-dbrc` library.

If you want your models to support multiple primary keys, then you will
need to install the `composite_primary_keys` library.

If you want date format validations, then you will need to install the
`validates_timeliness` library.

## Database Support
* **Oracle**: Full support via ruby-oci8
* **SQL Server**: Full support via tiny_tds
* **PostgreSQL**: Full support via pg
* **Auto-detection**: Automatically detects database type based on connection parameters

## Author's Comments
Originally focused only on Oracle, this library has been expanded to support
SQL Server and PostgreSQL as well. The architecture now supports multiple
database vendors, making it easy to add support for additional databases in
the future.

## Current Features
* **Multi-database support**: Oracle, SQL Server, and PostgreSQL
* **Auto-detection**: Automatically detects database type
* **Index recommendations**: Suggests optimal indexes for your tables
* **Multiple test frameworks**: Supports test-unit, minitest, and rspec
* **Docker support**: Complete Docker environments for testing all databases
* **Enum detection**: Automatically detects enum columns from CHECK constraints
* **Polymorphic associations**: Identifies polymorphic relationship patterns

## Future Plans (originally)
* Add support for views.

## Acknowlegements
Thanks go to Daniel Luna for his --class patch.

## Known Issues
None known. If you find any issues, please report them on the github project
page at http://www.github.com/djberg96/database-model-generator.

## Warranty
This package is provided "as is" and without any express or
implied warranties, including, without limitation, the implied
warranties of merchantability and fitness for a particular purpose.

## Copyright
(C) 2010-2025 Daniel J. Berger
All Rights Reserved

## License
Apache-2.0

## Author
Daniel J. Berger
