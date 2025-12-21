FROM ruby:3.2-alpine

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    git

# Set working directory
WORKDIR /app

# Copy gemspec and Gemfile
COPY database-model-generator.gemspec Gemfile ./
COPY lib/database_model_generator.rb lib/

# Install Ruby dependencies
RUN bundle install

# Copy the rest of the application
COPY . .

CMD ["bundle", "exec", "rspec", "spec/postgresql_model_generator_spec.rb"]
