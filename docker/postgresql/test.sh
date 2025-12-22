#!/bin/bash
set -e

echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is up - running tests"

# Install dependencies if needed
bundle check || bundle install

# Run the tests
bundle exec rspec spec/postgresql_model_generator_spec.rb -fd

echo "Tests completed!"
