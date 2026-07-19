# syntax=docker/dockerfile:1
#
# Single-stage image used for every service in docker-compose.yml (web, worker,
# ingest, test). Deliberately NOT the production/Kamal multi-stage image that
# Rails generates by default: the reviewer runs everything locally in the
# development/test environments, and the `test` service needs the development
# and test gem groups installed. Keeping one simple image keeps the take-home
# easy to reason about.

ARG RUBY_VERSION=3.3.12
FROM docker.io/library/ruby:$RUBY_VERSION-slim

# Packages needed to build native gems (pg) and talk to Postgres from the CLI.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git libpq-dev postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /rails

# Install gems first so this layer is cached across code changes.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Application code.
COPY . .

# Entrypoint ensures the database exists and is migrated before any command.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
