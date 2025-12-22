require_relative '../../database_model_generator'

begin
  require 'pg'
rescue LoadError
  # pg not available - PostgreSQL support will be disabled
end

module Postgresql
  module Model
    class Generator < DatabaseModel::Generator::Base
      VERSION = DatabaseModel::Generator::VERSION

      private

      def validate_connection(connection)
        unless defined?(PG) && connection.is_a?(PG::Connection)
          raise ArgumentError, "Connection must be a PG::Connection object. Install 'pg' gem for PostgreSQL support."
        end
      end

      def normalize_table_name(table)
        table.downcase # PostgreSQL uses lowercase for table names by convention
      end

      def check_table_exists(table)
        begin
          sql = "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = $1"
          result = @connection.exec_params(sql, [table.downcase])
          row = result.first
          result.clear
          row && row['count'].to_i > 0
        rescue => e
          puts "Error checking table existence: #{e.message}"
          false
        end
      end

      def get_column_info
        begin
          sql = <<~SQL
            SELECT
              column_name,
              data_type,
              character_maximum_length,
              numeric_precision,
              numeric_scale,
              is_nullable,
              column_default,
              udt_name
            FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = $1
            ORDER BY ordinal_position
          SQL

          result = @connection.exec_params(sql, [@table])
          @column_info = []

          result.each do |row|
            @column_info << PostgresqlColumnInfo.new(row)
          end

          result.clear
        rescue => e
          raise "Error retrieving column information: #{e.message}"
        end
      end

      def get_primary_keys
        begin
          sql = <<~SQL
            SELECT a.attname AS column_name
            FROM pg_index i
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
            WHERE i.indrelid = $1::regclass AND i.indisprimary
            ORDER BY a.attnum
          SQL

          result = @connection.exec_params(sql, [@table])
          @primary_keys = []

          result.each do |row|
            @primary_keys << row['column_name']
          end

          result.clear
        rescue => e
          raise "Error retrieving primary keys: #{e.message}"
        end
      end

      def get_foreign_keys
        begin
          sql = <<~SQL
            SELECT
              kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            WHERE tc.table_schema = 'public'
              AND tc.table_name = $1
              AND tc.constraint_type = 'FOREIGN KEY'
          SQL

          result = @connection.exec_params(sql, [@table])
          @foreign_keys = []

          result.each do |row|
            @foreign_keys << row['column_name']
          end

          result.clear
        rescue => e
          raise "Error retrieving foreign keys: #{e.message}"
        end
      end

      def get_constraints
        begin
          sql = <<~SQL
            SELECT
              tc.constraint_name,
              tc.constraint_type,
              kcu.column_name,
              cc.check_clause
            FROM information_schema.table_constraints tc
            LEFT JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            LEFT JOIN information_schema.check_constraints cc
              ON tc.constraint_name = cc.constraint_name
              AND tc.constraint_schema = cc.constraint_schema
            WHERE tc.table_schema = 'public'
              AND tc.table_name = $1
          SQL

          result = @connection.exec_params(sql, [@table])
          @constraints = []

          result.each do |row|
            @constraints << {
              'CONSTRAINT_NAME' => row['constraint_name'],
              'CONSTRAINT_TYPE' => row['constraint_type'],
              'COLUMN_NAME' => row['column_name'],
              'CHECK_CLAUSE' => row['check_clause']
            }
          end

          result.clear
        rescue => e
          raise "Error retrieving constraints: #{e.message}"
        end
      end

      def get_dependencies
        begin
          sql = <<~SQL
            SELECT
              dependent_ns.nspname AS dependent_schema,
              dependent_view.relname AS dependent_view,
              source_table.relname AS source_table
            FROM pg_depend
            JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
            JOIN pg_class AS dependent_view ON pg_rewrite.ev_class = dependent_view.oid
            JOIN pg_class AS source_table ON pg_depend.refobjid = source_table.oid
            JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
            WHERE source_table.relname = $1
              AND dependent_ns.nspname = 'public'
              AND source_table.relname != dependent_view.relname
          SQL

          result = @connection.exec_params(sql, [@table])
          @dependencies = []

          result.each do |row|
            @dependencies << {
              'NAME' => row['dependent_view'],
              'TYPE' => 'VIEW'
            }
          end

          result.clear
        rescue => e
          # Dependencies query may fail on some PostgreSQL versions, continue without error
          @dependencies = []
        end
      end

      def format_constraint_type(constraint)
        case constraint['CONSTRAINT_TYPE']
        when 'PRIMARY KEY' then 'Primary Key'
        when 'FOREIGN KEY' then 'Foreign Key'
        when 'UNIQUE' then 'Unique'
        when 'CHECK' then 'Check'
        else constraint['CONSTRAINT_TYPE']
        end
      end

      def get_constraint_column_name(constraint)
        constraint['COLUMN_NAME']
      end

      def get_constraint_text(constraint)
        constraint['CHECK_CLAUSE']
      end

      def is_string_type?(column)
        column.data_type.downcase =~ /(char|varchar|character varying|text|bpchar)/
      end

      def is_date_type?(column)
        column.data_type.downcase =~ /(date|time|timestamp)/
      end

      def is_text_type?(column)
        column.data_type.downcase =~ /(varchar|character varying|text|char)/
      end

      def get_column_size(column)
        column.character_maximum_length
      end

      def build_full_text_index_sql(column)
        "CREATE INDEX idx_#{@table.downcase}_#{column.name.downcase}_text ON #{@table.downcase} USING GIN (to_tsvector('english', #{column.name.downcase}))"
      end

      def get_full_text_index_type
        "PostgreSQL Full-Text Search (GIN Index)"
      end

      def find_fk_table(fk)
        # PostgreSQL-specific logic for finding referenced table
        # Try to get actual referenced table from foreign key constraints
        begin
          sql = <<~SQL
            SELECT
              ccu.table_name AS referenced_table
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage ccu
              ON tc.constraint_name = ccu.constraint_name
              AND tc.table_schema = ccu.table_schema
            WHERE tc.table_schema = 'public'
              AND tc.table_name = $1
              AND tc.constraint_type = 'FOREIGN KEY'
              AND kcu.column_name = $2
          SQL

          result = @connection.exec_params(sql, [@table, fk])
          row = result.first
          if row && row['referenced_table']
            result.clear
            return row['referenced_table'].downcase
          end
          result.clear
        rescue => e
          # Fall back to naming convention if query fails
        end

        # Fallback to naming convention
        fk.gsub(/_id$/i, '').pluralize rescue "#{fk.gsub(/_id$/i, '')}s"
      end

      def disconnect
        @connection.close if @connection && !@connection.finished?
      end
    end

    # PostgreSQL column info wrapper
    class PostgresqlColumnInfo
      attr_reader :name, :data_type, :character_maximum_length, :numeric_precision, :numeric_scale, :nullable, :column_default, :udt_name

      def initialize(row)
        @name = row['column_name']
        @data_type = row['data_type']
        @character_maximum_length = row['character_maximum_length']&.to_i
        @numeric_precision = row['numeric_precision']&.to_i
        @numeric_scale = row['numeric_scale']&.to_i
        @nullable = row['is_nullable'] == 'YES'
        @column_default = row['column_default']
        @udt_name = row['udt_name'] # PostgreSQL-specific user-defined type name
      end

      def nullable?
        @nullable
      end

      def data_size
        @character_maximum_length
      end

      def precision
        @numeric_precision
      end

      def scale
        @numeric_scale
      end
    end
  end
end
