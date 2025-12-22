# PostgreSQL Docker Setup for Database Model Generator

This directory contains Docker setup files for testing the PostgreSQL model generator.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1. Start the PostgreSQL container:

```bash
cd docker/postgresql
docker-compose up -d postgres-db
```

2. Wait for PostgreSQL to be ready (check with):

```bash
docker-compose logs -f postgres-db
```

3. Run the tests:

```bash
docker-compose run --rm dmg_test
```

Or run tests directly:

```bash
docker-compose run --rm dmg_test bundle exec rspec spec/postgresql_model_generator_spec.rb
```

## Environment Variables

The following environment variables are available:

- `POSTGRES_HOST`: PostgreSQL host (default: postgres-db)
- `POSTGRES_PORT`: PostgreSQL port (default: 5432)
- `POSTGRES_USER`: PostgreSQL username (default: postgres)
- `POSTGRES_PASSWORD`: PostgreSQL password (optional, omit if using trust authentication)
- `POSTGRES_DATABASE`: PostgreSQL database name (default: test_db)

## Sample Database

The `init-db.sql` file creates a sample database schema with:

- **users** table - with status and role enum columns
- **posts** table - with foreign key to users, status and priority enums
- **comments** table - with polymorphic association (commentable)
- **tags** table - simple lookup table
- **post_tags** table - many-to-many join table

This schema is designed to test various features of the model generator including:
- Foreign key detection
- Enum column detection
- Polymorphic associations
- Primary keys
- Constraints
- Indexes
- Full-text search recommendations

## Manual Testing

To connect to PostgreSQL manually:

```bash
docker-compose exec postgres-db psql -U postgres -d test_db
```

## Stopping and Cleaning Up

Stop the containers:

```bash
docker-compose down
```

Stop and remove volumes (warning: this deletes all data):

```bash
docker-compose down -v
```

## Troubleshooting

### PostgreSQL won't start

Check the logs:

```bash
docker-compose logs postgres-db
```

### Connection refused

Make sure the healthcheck passes:

```bash
docker-compose ps
```

The postgres-db service should show as "healthy".

### Tests fail

Ensure the database is initialized properly:

```bash
docker-compose exec postgres-db psql -U postgres -d test_db -c "\dt"
```

You should see the tables listed.
