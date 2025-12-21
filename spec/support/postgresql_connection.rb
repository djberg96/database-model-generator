require 'pg'

# Shared context for PostgreSQL database connection and test data
RSpec.shared_context 'PostgreSQL connection' do
  before(:context) do
    @pg_connection = begin
      # In Docker environment, use the service name instead of localhost
      host = ENV['POSTGRES_HOST'] || 'localhost'
      port = ENV['POSTGRES_PORT'] || '5432'
      database = ENV['POSTGRES_DATABASE'] || 'test_db'
      user = ENV['POSTGRES_USER'] || 'postgres'
      password = ENV['POSTGRES_PASSWORD'] || 'postgres'

      PG.connect(
        host: host,
        port: port,
        dbname: database,
        user: user,
        password: password
      )
    rescue PG::Error => e
      warn "Database connection failed: #{e.message}"
      warn "Make sure PostgreSQL database is running and accessible"
      warn "Connection string: #{host}:#{port}/#{database}"
      warn "User: #{user}"
      raise e
    end

    # Ensure test data exists
    setup_test_data
  end

  after(:context) do
    # Cleanup test data if needed
    cleanup_test_data

    # Close the connection
    @pg_connection&.close
  end

  # Use a method instead of let for context-level variables
  def connection
    @pg_connection
  end

  private

  def setup_test_data
    # The init-db.sql script should have already created the tables and data
    # This is just a verification step
    begin
      result = @pg_connection.exec("SELECT COUNT(*) FROM users")
      count = result.first['count'].to_i
      result.clear

      if count == 0
        warn "Warning: Test data not found. Make sure init-db.sql has been run."
      end
    rescue PG::Error => e
      warn "Error checking test data: #{e.message}"
    end
  end

  def cleanup_test_data
    # In Docker environment, we don't need to cleanup as containers are disposable
    # In local environment, you might want to clean up test data here
    # For now, we'll leave the data intact for debugging purposes
  end
end
