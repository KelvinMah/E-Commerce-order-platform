FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev libyaml-dev git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile ./
RUN bundle install
COPY . .
EXPOSE 3000
CMD ["bash", "-lc", "bundle exec rails db:prepare && bundle exec rails server -b 0.0.0.0"]
