require 'spec_helper'
require 'support/postgresql_connection'
require 'postgresql/model/generator'

RSpec.describe Postgresql::Model::Generator do
  include_context 'PostgreSQL connection'

  let(:generator) { described_class.new(connection) }

  describe 'class information' do
    it 'has the correct version number' do
      expect(Postgresql::Model::Generator::VERSION).to eq('0.6.1')
    end
  end

  describe '#initialize' do
    it 'accepts a PG::Connection object' do
      expect { described_class.new(connection) }.not_to raise_error
    end

    it 'sets up instance variables correctly' do
      expect(generator.connection).to eq(connection)
      expect(generator.constraints).to eq([])
      expect(generator.primary_keys).to eq([])
      expect(generator.foreign_keys).to eq([])
      expect(generator.dependencies).to eq([])
      expect(generator.belongs_to).to eq([])
      expect(generator.column_info).to eq([])
      expect(generator.table).to be_nil
      expect(generator.model).to be_nil
    end

    it 'raises an error if connection is nil' do
      expect { described_class.new(nil) }.to raise_error(ArgumentError, /Connection cannot be nil/)
    end

    it 'raises an error if connection is not a PG::Connection' do
      expect { described_class.new("not a connection") }.to raise_error(ArgumentError, /must be a PG::Connection/)
    end
  end

  describe '#generate' do
    it 'responds to the generate method' do
      expect(generator).to respond_to(:generate)
    end

    it 'works with a table name' do
      expect { generator.generate('users') }.not_to raise_error
    end

    it 'raises an error for nil table name' do
      expect { generator.generate(nil) }.to raise_error(ArgumentError, /Table name cannot be nil/)
    end

    it 'raises an error for empty table name' do
      expect { generator.generate('') }.to raise_error(ArgumentError, /Table name cannot be nil/)
    end

    context 'when generating from the users table' do
      before { generator.generate('users') }

      it 'sets the table name in lowercase' do
        expect(generator.table).to eq('users')
      end

      it 'generates a model name from the table name' do
        expect(generator.model).to eq('User')
      end

      it 'sets view to false' do
        expect(generator.view).to be false
      end

      it 'populates column information' do
        expect(generator.column_info).to be_an(Array)
        expect(generator.column_info).not_to be_empty

        column_names = generator.column_info.map(&:name)
        expect(column_names).to include('id')
        expect(column_names).to include('username')
        expect(column_names).to include('email')
        expect(column_names).to include('status')
        expect(column_names).to include('role')
      end

      it 'finds primary keys' do
        expect(generator.primary_keys).to be_an(Array)
        expect(generator.primary_keys).to include('id')
      end

      it 'populates constraints information' do
        expect(generator.constraints).to be_an(Array)
        expect(generator.constraints).not_to be_empty
      end

      it 'detects enum columns' do
        expect(generator.has_enum_columns?).to be true
        enum_column_names = generator.enum_column_names
        expect(enum_column_names).to include('status')
        expect(enum_column_names).to include('role')
      end

      it 'extracts enum values from constraints' do
        generator.generate('users')
        status_enum = generator.enum_columns.find { |e| e[:name] == 'status' }
        expect(status_enum).not_to be_nil
        expect(status_enum[:values]).to include('active', 'inactive', 'suspended', 'deleted')
      end
    end

    context 'when generating from the posts table' do
      before { generator.generate('posts') }

      it 'sets the table name in lowercase' do
        expect(generator.table).to eq('posts')
      end

      it 'generates the correct model name' do
        expect(generator.model).to eq('Post')
      end

      it 'finds foreign keys' do
        expect(generator.foreign_keys).to be_an(Array)
        expect(generator.foreign_keys).to include('user_id')
      end

      it 'identifies belongs_to associations' do
        expect(generator.belongs_to).to be_an(Array)
        expect(generator.belongs_to).to include('users')
      end

      it 'detects multiple enum columns' do
        enum_column_names = generator.enum_column_names
        expect(enum_column_names).to include('status')
        expect(enum_column_names).to include('priority')
      end

      it 'extracts enum values for status' do
        status_enum = generator.enum_columns.find { |e| e[:name] == 'status' }
        expect(status_enum).not_to be_nil
        expect(status_enum[:values]).to include('draft', 'published', 'archived')
      end

      it 'extracts enum values for priority' do
        priority_enum = generator.enum_columns.find { |e| e[:name] == 'priority' }
        expect(priority_enum).not_to be_nil
        expect(priority_enum[:values]).to include('low', 'medium', 'high', 'urgent')
      end
    end

    context 'when generating from the comments table' do
      before { generator.generate('comments') }

      it 'detects polymorphic associations' do
        expect(generator.has_polymorphic_associations?).to be true
        expect(generator.polymorphic_association_names).to include('commentable')
      end

      it 'identifies polymorphic foreign keys and types' do
        poly_assoc = generator.polymorphic_associations.first
        expect(poly_assoc[:foreign_key]).to eq('commentable_id')
        expect(poly_assoc[:foreign_type]).to eq('commentable_type')
      end
    end

    context 'when generating from the post_tags table' do
      before { generator.generate('post_tags') }

      it 'detects composite primary keys' do
        expect(generator.primary_keys).to be_an(Array)
        expect(generator.primary_keys.length).to be >= 2
        expect(generator.primary_keys).to include('post_id')
        expect(generator.primary_keys).to include('tag_id')
      end

      it 'identifies multiple foreign keys' do
        expect(generator.foreign_keys).to include('post_id')
        expect(generator.foreign_keys).to include('tag_id')
      end
    end
  end

  describe '#table_exists?' do
    it 'returns true for existing tables' do
      generator.generate('users')
      expect(generator.table_exists?).to be true
    end

    it 'returns false for non-existing tables' do
      generator.generate('nonexistent_table')
      expect(generator.table_exists?).to be false
    end
  end

  describe '#generated?' do
    it 'returns false before generate is called' do
      expect(generator.generated?).to be false
    end

    it 'returns true after successful generation' do
      generator.generate('users')
      expect(generator.generated?).to be true
    end
  end

  describe '#column_names' do
    it 'returns an array of column names' do
      generator.generate('users')
      column_names = generator.column_names
      expect(column_names).to be_an(Array)
      expect(column_names).to include('id', 'username', 'email')
    end
  end

  describe '#constraint_summary' do
    it 'returns a hash of constraints by column' do
      generator.generate('users')
      summary = generator.constraint_summary
      expect(summary).to be_a(Hash)
    end
  end

  describe '#index_recommendations' do
    it 'returns index recommendations' do
      generator.generate('posts')
      recommendations = generator.index_recommendations

      expect(recommendations).to be_a(Hash)
      expect(recommendations).to have_key(:foreign_keys)
      expect(recommendations).to have_key(:date_queries)
      expect(recommendations).to have_key(:status_enum)
      expect(recommendations).to have_key(:composite)
      expect(recommendations).to have_key(:full_text)
    end

    it 'recommends indexes for foreign keys' do
      generator.generate('posts')
      recommendations = generator.index_recommendations

      fk_recommendations = recommendations[:foreign_keys]
      expect(fk_recommendations).not_to be_empty

      user_id_index = fk_recommendations.find { |r| r[:column] == 'user_id' }
      expect(user_id_index).not_to be_nil
    end

    it 'recommends indexes for date columns' do
      generator.generate('posts')
      recommendations = generator.index_recommendations

      date_recommendations = recommendations[:date_queries]
      created_at_index = date_recommendations.find { |r| r[:column] == 'created_at' }
      expect(created_at_index).not_to be_nil if date_recommendations.any?
    end

    it 'recommends full-text indexes for text columns' do
      generator.generate('posts')
      recommendations = generator.index_recommendations

      fulltext_recommendations = recommendations[:full_text]
      expect(fulltext_recommendations).to be_an(Array)
    end
  end

  describe '#enum_definitions' do
    it 'generates Rails enum definitions' do
      generator.generate('users')
      definitions = generator.enum_definitions

      expect(definitions).to be_an(Array)
      expect(definitions).not_to be_empty

      # Check that definitions are in the correct format
      definitions.each do |definition|
        expect(definition).to match(/^enum \w+: \{.+\}$/)
      end
    end
  end

  describe '#polymorphic_has_many_suggestions' do
    it 'suggests has_many associations for polymorphic parents' do
      generator.generate('comments')
      suggestions = generator.polymorphic_has_many_suggestions

      expect(suggestions).to be_an(Array)
      expect(suggestions).not_to be_empty if generator.has_polymorphic_associations?
    end
  end

  describe '#model' do
    it 'returns the active record model name' do
      generator.generate('users')
      expect(generator.model).to eq('User')
    end

    it 'removes trailing s from model names' do
      generator.generate('posts')
      expect(generator.model).to eq('Post')
    end

    it 'handles underscored table names' do
      generator.generate('post_tags')
      expect(generator.model).to eq('PostTag')
    end
  end

  describe '#disconnect' do
    it 'closes the database connection' do
      test_conn = PG.connect(
        host: ENV['POSTGRES_HOST'] || 'localhost',
        port: ENV['POSTGRES_PORT'] || '5432',
        dbname: ENV['POSTGRES_DATABASE'] || 'test_db',
        user: ENV['POSTGRES_USER'] || 'postgres',
        password: ENV['POSTGRES_PASSWORD'] || 'postgres'
      )

      test_gen = described_class.new(test_conn)
      test_gen.disconnect

      expect(test_conn.finished?).to be true
    end
  end
end
