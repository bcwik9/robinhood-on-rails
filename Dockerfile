FROM ruby:2.2.2

WORKDIR $HOME/

RUN git clone https://github.com/bcwik9/robinhood-on-rails.git
RUN cd robinhood-on-rails


COPY Gemfile* $HOME/
RUN bundle install

ADD . $HOME
RUN bundle exec rake db:create db:migrate

#CMD ["bundle", "exec", "rails", "server"]
CMD rails server -e development -b 0.0.0.0 -p 3000
