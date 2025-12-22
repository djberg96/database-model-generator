# PostgreSQL Support

This document describes the PostgreSQL implementation for the database-model-generator library.

## Overview

PostgreSQL support has been added to the database-model-generator library, allowing you to generate ActiveRecord models from existing PostgreSQL tables and views. The implementation follows the same architecture as Oracle and SQL Server support.

## Features

The PostgreSQL generator includes:

- **Full table introspection** via PostgreSQL's `information_schema`
- **Primary key detection** using `pg_index` and `pg_attribute`
- **Foreign key detection** with automatic relationship inference
- **Constraint detection** including CHECK, UNIQUE, and NOT NULL constraints
- **Enum detection** from CHECK constraints with IN clauses
- **Polymorphic association detection** (e.g., commentable_id + commentable_type)
- **Index recommendations** for foreign keys, dates, text search, and composite indexes
- **Full-text search support** using PostgreSQL's GIN indexes and tsvector
- **Dependency tracking** for views and related objects

## Installation

Add the `pg` gem to your Gemfile or install it directly:

```bash
gem install pg
```

## Usage

### With the Command Line Tool

```bash
# Using explicit database type
dmg -T postgresql -h localhost -d your_database -t users -u postgres [-p password]

# Using auto-detection (if connection parameters indicate PostgreSQL)
dmg -h localhost -d your_database -t users -u postgres [-p password]

# Password is optional if pg_hba.conf is configured for trust authentication
dmg -T postgresql -h localhost -d your_database -t users -u postgres
```

### Programmatically

```ruby
require 'pg'
require 'database_model_generator'

# Connect to PostgreSQL
# Note: password is optional if pg_hba.conf allows trust authentication
conn = PG.connect(
  host: 'localhost',
  port: 5432,
  dbname: 'your_database',
  user: 'postgres'
  # password: 'your_password'  # Only needed if authentication is required
)

# Create a generator instance
generator = DatabaseModel::Generator.new(conn)

# Generate model information
generator.generate('users')

# Access model information
puts "Model name: #{generator.model}"
puts "Table name: #{generator.table}"
puts "Columns: #{generator.column_names.join(', ')}"
puts "Primary keys: #{generator.primary_keys.join(', ')}"
puts "Foreign keys: #{generator.foreign_keys.join(', ')}"

# Get enum columns
if generator.has_enum_columns?
  puts "\nEnum columns detected:"
  generator.enum_columns.each do |enum_col|
    puts "  #{enum_col[:name]}: #{enum_col[:values].join(', ')}"
  end
end

# Get polymorphic associations
if generator.has_polymorphic_associations?
  puts "\nPolymorphic associations:"
  generator.polymorphic_associations.each do |assoc|
    puts "  #{assoc[:name]} (#{assoc[:foreign_key]}, #{assoc[:foreign_type]})"
  end
end

# Get index recommendations
recommendations = generator.index_recommendations
puts "\nIndex recommendations:"
recommendations[:foreign_keys].each do |rec|
  puts "  #{rec[:sql]}"
end

# Close connection
generator.disconnect
```

## PostgreSQL-Specific Features

### Full-Text Search

PostgreSQL's powerful full-text search is supported through GIN indexes:

```ruby
generator.generate('posts')
recommendations = generator.index_recommendations

# Full-text recommendations use to_tsvector
recommendations[:full_text].each do |rec|
  puts rec[:sql]
  # CREATE INDEX idx_posts_content_text ON posts
  #   USING GIN (to_tsvector('english', content))
end
```

### Enum Detection from CHECK Constraints

PostgreSQL CHECK constraints are parsed to detect enum columns:

```sql
CREATE TABLE users (
  status VARCHAR(20) DEFAULT 'active',
  CONSTRAINT check_status CHECK (status IN ('active', 'inactive', 'suspended'))
);
```

```ruby
generator.generate('users')
generator.enum_columns
# => [{name: 'status', values: ['active', 'inactive', 'suspended'], ...}]
```

### Data Type Support

The PostgreSQL generator handles all standard PostgreSQL data types:

- **Character types**: CHAR, VARCHAR, TEXT, CHARACTER VARYING
- **Numeric types**: INTEGER, BIGINT, DECIMAL, NUMERIC, REAL, DOUBLE PRECISION
- **Date/Time types**: DATE, TIME, TIMESTAMP, TIMESTAMPTZ, INTERVAL
- **Boolean type**: BOOLEAN
- **Binary types**: BYTEA
- **JSON types**: JSON, JSONB
- **Arrays and custom types**: Detected via `udt_name` column

## Testing

### Using Docker

The easiest way to test PostgreSQL support is using the provided Docker setup:

```bash
cd docker/postgresql

# Start PostgreSQL
docker-compose up -d postgres-db

# Wait for it to be healthy
docker-compose ps

# Run tests
docker-compose run --rm dmg_test
```

### Manual Testing

If you have PostgreSQL installed locally:

```bash
# Create test database
createdb test_db

# Run initialization script
psql -d test_db -f docker/postgresql/init-db.sql

# Run tests
bundle exec rspec spec/postgresql_model_generator_spec.rb
```

## Database Schema Example

The test database includes:

- **users** - with status and role enum columns
- **posts** - with foreign key to users, status and priority enums
- **comments** - with polymorphic association (commentable)
- **tags** - simple lookup table
- **post_tags** - many-to-many join table with composite primary key

## Architecture

The PostgreSQL generator is implemented in `lib/postgresql/model/generator.rb` and extends the `DatabaseModel::Generator::Base` class, providing PostgreSQL-specific implementations for:

- `validate_connection` - ensures connection is a `PG::Connection`
- `normalize_table_name` - converts to lowercase (PostgreSQL convention)
- `check_table_exists` - queries `information_schema.tables`
- `get_column_info` - retrieves column metadata
- `get_primary_keys` - queries `pg_index` system catalog
- `get_foreign_keys` - queries `information_schema.table_constraints`
- `get_constraints` - retrieves all constraint information
- `get_dependencies` - finds dependent views and objects
- Type checking methods for PostgreSQL data types

## Comparison with Other Databases

| Feature | Oracle | SQL Server | PostgreSQL |
|---------|--------|------------|------------|
| Connection | OCI8 | TinyTds::Client | PG::Connection |
| Schema queries | USER_* views | INFORMATION_SCHEMA | INFORMATION_SCHEMA + pg_* |
| Table name case | UPPERCASE | Case-sensitive | lowercase |
| Full-text search | Oracle Text | FULLTEXT INDEX | GIN + tsvector |
| Enum detection | ✓ | ✓ | ✓ |
| Polymorphic | ✓ | ✓ | ✓ |
| Composite PKs | ✓ | ✓ | ✓ |

## Troubleshooting

### Connection Issues

If you get connection errors:

```ruby
PG::ConnectionBad: could not connect to server
```

Check:
1. PostgreSQL is running: `pg_isready`
2. Connection parameters are correct
3. User has proper permissions
4. `pg_hba.conf` allows the connection

### Missing Tables

If tables aren't found:

```ruby
generator.table_exists? # => false
```

Check:
1. Table is in the `public` schema (or adjust schema in queries)
2. User has SELECT permission on the table
3. Table name is correct (case-sensitive in PostgreSQL when quoted)

### Gem Installation Issues

On macOS with Homebrew PostgreSQL:

```bash
gem install pg -- --with-pg-config=/usr/local/bin/pg_config
```

Or with a specific PostgreSQL version:

```bash
gem install pg -- --with-pg-config=/usr/local/opt/postgresql@14/bin/pg_config
```

## Future Enhancements

Possible future improvements:

- Support for PostgreSQL-specific features (arrays, JSON columns)
- Custom type (enum, composite) detection
- Partitioned table support
- Foreign data wrapper detection
- Materialized view support
- PostgreSQL extension detection (PostGIS, etc.)

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [pg gem documentation](https://github.com/ged/ruby-pg)
- [PostgreSQL INFORMATION_SCHEMA](https://www.postgresql.org/docs/current/information-schema.html)
- [PostgreSQL System Catalogs](https://www.postgresql.org/docs/current/catalogs.html)
