begin
  require 'oci8'
rescue LoadError
  # OCI8 not available - Oracle support will be disabled
end

begin
  require 'tiny_tds'
rescue LoadError
  # TinyTDS not available - SQL Server support will be disabled
end

begin
  require 'pg'
rescue LoadError
  # pg not available - PostgreSQL support will be disabled
end

module DatabaseModel
  module Generator
    # The version of the database-model-generator library
    VERSION = '0.6.1'

    # Factory method to create the appropriate generator based on connection type
    def self.new(connection, options = {})
      database_type = detect_database_type(connection, options)

      case database_type
      when :oracle
        require_relative 'oracle/model/generator'
        Oracle::Model::Generator.new(connection)
      when :sqlserver
        require_relative 'sqlserver/model/generator'
        SqlServer::Model::Generator.new(connection)
      when :postgresql
        require_relative 'postgresql/model/generator'
        Postgresql::Model::Generator.new(connection)
      else
        raise ArgumentError, "Unsupported database type: #{database_type}"
      end
    end

    private

    def self.detect_database_type(connection, options = {})
      return options[:type].to_sym if options[:type]

      case connection.class.name
      when 'OCI8'
        :oracle
      when 'TinyTds::Client'
        :sqlserver
      when 'PG::Connection'
        :postgresql
      else
        raise ArgumentError, "Cannot detect database type from connection: #{connection.class}"
      end
    end
  end
end

# Base generator class with common functionality
module DatabaseModel
  module Generator
    class Base
      attr_reader :connection, :constraints, :foreign_keys, :belongs_to
      attr_reader :table, :model, :view, :dependencies, :column_info, :primary_keys
      attr_reader :polymorphic_associations, :enum_columns

      def initialize(connection)
        raise ArgumentError, "Connection cannot be nil" if connection.nil?
        validate_connection(connection)

        @connection   = connection
        @constraints  = []
        @primary_keys = []
        @foreign_keys = []
        @dependencies = []
        @belongs_to   = []
        @polymorphic_associations = []
        @enum_columns = []
        @column_info  = []
        @table        = nil
        @model        = nil
      end

      def generate(table, view = false)
        raise ArgumentError, "Table name cannot be nil or empty" if table.nil? || table.strip.empty?

        @table = normalize_table_name(table)
        @model = generate_model_name(table)
        @view  = view

        reset_state
        get_column_info
        get_primary_keys
        get_foreign_keys unless view
        get_belongs_to
        get_constraints unless view
        get_polymorphic_associations unless view
        get_enum_columns unless view
        get_dependencies unless view

        self
      end

      def generated?
        !@table.nil? && !@column_info.empty?
      end

      def column_names
        return [] unless generated?
        @column_info.map(&:name)
      end

      def table_exists?
        return false unless @table
        check_table_exists(@table)
      end

      def disconnect
        # Default implementation - subclasses should override
        @connection = nil
      end

      def constraint_summary
        return {} unless generated?

        summary = Hash.new { |h, k| h[k] = [] }
        @constraints.each do |constraint|
          type = format_constraint_type(constraint)
          column_name = get_constraint_column_name(constraint)
          summary[column_name.downcase] << type
        end
        summary
      end

      def index_recommendations
        return {} unless generated?

        recommendations = {
          foreign_keys: [],
          unique_constraints: [],
          date_queries: [],
          status_enum: [],
          composite: [],
          full_text: []
        }

        build_foreign_key_recommendations(recommendations)
        build_unique_constraint_recommendations(recommendations)
        build_date_recommendations(recommendations)
        build_status_recommendations(recommendations)
        build_composite_recommendations(recommendations)
        build_full_text_recommendations(recommendations)

        recommendations
      end

      private

      # Abstract methods to be implemented by database-specific subclasses
      def validate_connection(connection)
        raise NotImplementedError, "Subclasses must implement validate_connection"
      end

      def normalize_table_name(table)
        raise NotImplementedError, "Subclasses must implement normalize_table_name"
      end

      def check_table_exists(table)
        raise NotImplementedError, "Subclasses must implement check_table_exists"
      end

      def get_column_info
        raise NotImplementedError, "Subclasses must implement get_column_info"
      end

      def get_primary_keys
        raise NotImplementedError, "Subclasses must implement get_primary_keys"
      end

      def get_foreign_keys
        raise NotImplementedError, "Subclasses must implement get_foreign_keys"
      end

      def get_constraints
        raise NotImplementedError, "Subclasses must implement get_constraints"
      end

      def get_dependencies
        raise NotImplementedError, "Subclasses must implement get_dependencies"
      end

      def format_constraint_type(constraint)
        raise NotImplementedError, "Subclasses must implement format_constraint_type"
      end

      def get_constraint_column_name(constraint)
        raise NotImplementedError, "Subclasses must implement get_constraint_column_name"
      end

      # Common implementation methods
      def reset_state
        @constraints.clear
        @primary_keys.clear
        @foreign_keys.clear
        @dependencies.clear
        @belongs_to.clear
        @polymorphic_associations.clear
        @enum_columns.clear
        @column_info.clear
      end

      def generate_model_name(table)
        model = table.dup
        model.downcase!
        model.chop! if model[-1].chr.downcase == 's'
        model.split('_').map(&:capitalize).join
      end

      def get_belongs_to
        @belongs_to = @foreign_keys.map { |fk| find_fk_table(fk) }.compact
      end

      def get_polymorphic_associations
        @polymorphic_associations = detect_polymorphic_associations
      end

      def get_enum_columns
        @enum_columns = detect_enum_columns
      end

      def detect_enum_columns
        enum_columns = []

        @column_info.each do |col|
          next unless is_string_type?(col)

          column_name = col.name.downcase

          # Check for common enum-like column names
          if enum_candidate?(column_name)
            enum_info = {
              name: col.name,
              column_name: column_name,
              suggested_values: suggest_enum_values(column_name),
              type: determine_enum_type(column_name)
            }

            # Try to get actual values from constraints if available
            constraint_values = extract_constraint_values(col.name)
            if constraint_values.any?
              enum_info[:values] = constraint_values
              enum_info[:source] = 'check_constraint'
            else
              enum_info[:values] = enum_info[:suggested_values]
              enum_info[:source] = 'pattern_matching'
            end

            enum_columns << enum_info
          end
        end

        enum_columns
      end

      private

      def enum_candidate?(column_name)
        # Common enum column patterns
        enum_patterns = [
          /^status$/,
          /^state$/,
          /^type$/,
          /^role$/,
          /^priority$/,
          /^level$/,
          /^category$/,
          /^kind$/,
          /^mode$/,
          /^visibility$/,
          /_status$/,
          /_state$/,
          /_type$/,
          /_role$/,
          /_priority$/,
          /_level$/,
          /_category$/,
          /_kind$/,
          /_mode$/
        ]

        enum_patterns.any? { |pattern| column_name =~ pattern }
      end

      def suggest_enum_values(column_name)
        # Suggest common enum values based on column name patterns
        case column_name
        when /status/
          %w[active inactive pending approved rejected]
        when /state/
          %w[draft published archived]
        when /priority/
          %w[low medium high critical]
        when /level/
          %w[beginner intermediate advanced expert]
        when /role/
          %w[user admin moderator]
        when /visibility/
          %w[public private protected]
        when /category/
          %w[general news updates]
        when /type/
          %w[standard premium basic]
        when /mode/
          %w[automatic manual]
        else
          %w[option1 option2 option3]
        end
      end

      def determine_enum_type(column_name)
        # Determine if enum should use string or integer values
        case column_name
        when /status|state|priority|level|role|visibility/
          :string  # These are better as string enums for readability
        when /type|category|kind|mode/
          :string  # These are also better as strings
        else
          :integer # Default to integer for performance
        end
      end

      def extract_constraint_values(column_name)
        # Try to extract enum values from CHECK constraints
        values = []

        puts "DEBUG: Looking for constraints for column: #{column_name}" if ENV['DEBUG']
        puts "DEBUG: Available constraints: #{@constraints.length}" if ENV['DEBUG']

        @constraints.each do |constraint|
          puts "DEBUG: Checking constraint: #{constraint.inspect}" if ENV['DEBUG']
          if constraint_applies_to_column?(constraint, column_name)
            puts "DEBUG: Constraint applies to column #{column_name}" if ENV['DEBUG']
            constraint_values = parse_check_constraint_values(constraint)
            values.concat(constraint_values) if constraint_values.any?
          end
        end

        puts "DEBUG: Final extracted values for #{column_name}: #{values.inspect}" if ENV['DEBUG']
        values.uniq
      end

      def constraint_applies_to_column?(constraint, column_name)
        # Check if constraint applies to the specific column
        constraint_column = get_constraint_column_name(constraint)
        return false unless constraint_column

        constraint_column.downcase == column_name.downcase
      end

      def parse_check_constraint_values(constraint)
        # Parse CHECK constraint to extract possible enum values
        # This is database-specific and may need to be overridden
        values = []

        # Look for patterns like: column IN ('value1', 'value2', 'value3')
        # or: column = 'value1' OR column = 'value2'
        # or SQL Server: [column] IS NOT DISTINCT FROM 'value1' OR [column] IS NOT DISTINCT FROM 'value2'
        constraint_text = get_constraint_text(constraint)
        return values unless constraint_text

        puts "DEBUG: Parsing constraint: #{constraint_text}" if ENV['DEBUG']

        # Extract values from IN clause
        in_match = constraint_text.match(/IN\s*\(\s*([^)]+)\s*\)/i)
        if in_match
          values_text = in_match[1]
          # Extract quoted strings
          values = values_text.scan(/'([^']+)'/).flatten
          puts "DEBUG: Found IN values: #{values.inspect}" if ENV['DEBUG']
        else
          # Extract values from OR conditions (standard format)
          or_matches = constraint_text.scan(/=\s*'([^']+)'/i)
          if or_matches.any?
            values = or_matches.flatten
            puts "DEBUG: Found OR values: #{values.inspect}" if ENV['DEBUG']
          else
            # Extract values from SQL Server IS NOT DISTINCT FROM format
            distinct_matches = constraint_text.scan(/IS NOT DISTINCT FROM\s+'([^']+)'/i)
            if distinct_matches.any?
              values = distinct_matches.flatten
              puts "DEBUG: Found DISTINCT values: #{values.inspect}" if ENV['DEBUG']
            end
          end
        end

        values
      end

      def get_constraint_text(constraint)
        # This should be overridden by database-specific implementations
        # to return the actual constraint text/condition
        nil
      end

      public

      def detect_polymorphic_associations
        polymorphic_assocs = []
        column_names = @column_info.map { |col| col.name.downcase }

        # Look for patterns like: commentable_type + commentable_id
        # or imageable_type + imageable_id, etc.
        type_columns = column_names.select { |name| name.end_with?('_type') }

        type_columns.each do |type_col|
          base_name = type_col.gsub(/_type$/, '')
          id_col = "#{base_name}_id"

          if column_names.include?(id_col)
            # Check if this isn't already a regular foreign key
            unless @foreign_keys.map(&:downcase).include?(id_col)
              polymorphic_assocs << {
                name: base_name,
                foreign_key: id_col,
                foreign_type: type_col,
                association_name: base_name
              }
            end
          end
        end

        polymorphic_assocs
      end

      # Make sure these polymorphic methods are public
      public

      def has_polymorphic_associations?
        !@polymorphic_associations.empty?
      end

      def has_enum_columns?
        !@enum_columns.empty?
      end

      def enum_column_names
        @enum_columns.map { |enum_col| enum_col[:name] }
      end

      def enum_definitions
        # Generate Rails enum definitions
        definitions = []
        @enum_columns.each do |enum_col|
          if enum_col[:type] == :integer
            # Integer enum: { draft: 0, published: 1, archived: 2 }
            values = enum_col[:values].each_with_index.map { |val, idx| "#{val}: #{idx}" }.join(', ')
            definitions << "enum #{enum_col[:column_name]}: { #{values} }"
          else
            # String enum: { low: 'low', medium: 'medium', high: 'high' }
            values = enum_col[:values].map { |val| "#{val}: '#{val}'" }.join(', ')
            definitions << "enum #{enum_col[:column_name]}: { #{values} }"
          end
        end
        definitions
      end

      def enum_validation_suggestions
        # Suggest validations for enum columns
        suggestions = []
        @enum_columns.each do |enum_col|
          suggestions << {
            column: enum_col[:column_name],
            validation: "validates :#{enum_col[:column_name]}, inclusion: { in: #{enum_col[:column_name].pluralize}.keys }",
            description: "Validates #{enum_col[:column_name]} is a valid enum value"
          }
        end
        suggestions
      end

      def polymorphic_association_names
        @polymorphic_associations.map { |assoc| assoc[:name] }
      end

      def polymorphic_has_many_suggestions
        # Suggest has_many associations for models that could be polymorphic parents
        suggestions = []
        @polymorphic_associations.each do |assoc|
          # For a 'commentable' polymorphic association, suggest:
          # has_many :comments, as: :commentable, dependent: :destroy
          child_model = pluralize_for_has_many(assoc[:name])
          suggestions << {
            association: "has_many :#{child_model}, as: :#{assoc[:name]}, dependent: :destroy",
            description: "For models that can have #{child_model} (polymorphic)"
          }
        end
        suggestions
      end

      def find_fk_table(fk)
        # Default implementation - may be overridden by subclasses
        fk.gsub(/_id$/i, '').pluralize rescue "#{fk.gsub(/_id$/i, '')}s"
      end

      private

      def pluralize_for_has_many(singular_name)
        # Simple pluralization - can be enhanced
        case singular_name
        when /able$/
          # commentable -> comments, imageable -> images
          base = singular_name.gsub(/able$/, '')
          case base
          when 'comment' then 'comments'
          when 'image' then 'images'
          when 'tag' then 'tags'
          when 'like' then 'likes'
          when 'favorite' then 'favorites'
          else "#{base}s"
          end
        else
          "#{singular_name}s"
        end
      end

      public

      def find_fk_table(fk)
        # Default implementation - may be overridden by subclasses
        fk.gsub(/_id$/i, '').pluralize rescue "#{fk.gsub(/_id$/i, '')}s"
      end

      def build_foreign_key_recommendations(recommendations)
        @belongs_to.each do |table_ref|
          fk_column = "#{table_ref.downcase.gsub(/s$/, '')}_id"
          col = @column_info.find { |c| c.name.downcase == fk_column }
          if col
            recommendations[:foreign_keys] << {
              column: col.name.downcase,
              sql: "add_index :#{@table.downcase}, :#{col.name.downcase}",
              reason: "Foreign key index for #{col.name}"
            }
          end
        end
      end

      def build_unique_constraint_recommendations(recommendations)
        unique_columns = @column_info.select do |col|
          col.name.downcase =~ /(email|username|code|slug|uuid|token)/ ||
          (!col.nullable? && col.name.downcase =~ /(name|title)$/ && is_string_type?(col))
        end

        unique_columns.each do |col|
          recommendations[:unique_constraints] << {
            column: col.name.downcase,
            sql: "add_index :#{@table.downcase}, :#{col.name.downcase}, unique: true",
            reason: "Unique constraint for #{col.name}"
          }
        end
      end

      def build_date_recommendations(recommendations)
        date_columns = @column_info.select do |col|
          is_date_type?(col) ||
          col.name.downcase =~ /(created_at|updated_at|modified_date|start_date|end_date|due_date)/
        end

        date_columns.each do |col|
          recommendations[:date_queries] << {
            column: col.name.downcase,
            sql: "add_index :#{@table.downcase}, :#{col.name.downcase}",
            reason: "Date queries for #{col.name}"
          }
        end
      end

      def build_status_recommendations(recommendations)
        status_columns = @column_info.select do |col|
          col.name.downcase =~ /(status|state|type|role|priority|level|category)$/ &&
          is_string_type?(col)
        end

        status_columns.each do |col|
          recommendations[:status_enum] << {
            column: col.name.downcase,
            sql: "add_index :#{@table.downcase}, :#{col.name.downcase}",
            reason: "Status/enum queries for #{col.name}"
          }
        end
      end

      def build_composite_recommendations(recommendations)
        foreign_key_columns = recommendations[:foreign_keys].map { |fk| fk[:column] }
        date_column_names = recommendations[:date_queries].map { |d| d[:column] }
        status_column_names = recommendations[:status_enum].map { |s| s[:column] }

        if foreign_key_columns.any? && date_column_names.any?
          fk_col = foreign_key_columns.first
          date_col = date_column_names.find { |col| col =~ /created/ } || date_column_names.first
          recommendations[:composite] << {
            columns: [fk_col, date_col],
            sql: "add_index :#{@table.downcase}, [:#{fk_col}, :#{date_col}]",
            reason: "Composite index for filtering by #{fk_col} and #{date_col}"
          }
        end

        if status_column_names.any? && date_column_names.any?
          status_col = status_column_names.first
          date_col = date_column_names.find { |col| col =~ /created/ } || date_column_names.first
          recommendations[:composite] << {
            columns: [status_col, date_col],
            sql: "add_index :#{@table.downcase}, [:#{status_col}, :#{date_col}]",
            reason: "Composite index for filtering by #{status_col} and #{date_col}"
          }
        end
      end

      def build_full_text_recommendations(recommendations)
        text_search_columns = @column_info.select do |col|
          is_text_type?(col) &&
          col.name.downcase =~ /(name|title|description|content|text|search)/ &&
          (get_column_size(col).nil? || get_column_size(col) > 50)
        end

        text_search_columns.each do |col|
          recommendations[:full_text] << {
            column: col.name.downcase,
            sql: build_full_text_index_sql(col),
            reason: "Full-text search for #{col.name}",
            type: get_full_text_index_type
          }
        end
      end

      # Abstract helper methods for database-specific type checking
      def is_string_type?(column)
        raise NotImplementedError, "Subclasses must implement is_string_type?"
      end

      def is_date_type?(column)
        raise NotImplementedError, "Subclasses must implement is_date_type?"
      end

      def is_text_type?(column)
        raise NotImplementedError, "Subclasses must implement is_text_type?"
      end

      def get_column_size(column)
        raise NotImplementedError, "Subclasses must implement get_column_size"
      end

      def build_full_text_index_sql(column)
        raise NotImplementedError, "Subclasses must implement build_full_text_index_sql"
      end

      def get_full_text_index_type
        raise NotImplementedError, "Subclasses must implement get_full_text_index_type"
      end
    end
  end
end
