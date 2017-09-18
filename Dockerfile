FROM ruby:2.2.2

ADD . $HOME/robinhood-on-rails
WORKDIR $HOME/robinhood-on-rails

RUN bundle install

RUN bundle exec rake db:create db:migrate

#CMD ["bundle", "exec", "rails", "server"]
CMD rails server -e development -b 0.0.0.0 -p 3000
