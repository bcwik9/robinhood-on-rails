# Robinhood on Rails
Robinhood on Rails is a simple front end dashboard for the free trading platform [Robinhood](https://robinhood.com/).
![image](https://cloud.githubusercontent.com/assets/508449/24683808/751d6dde-196f-11e7-9a92-a7e7f95dd3e9.png)

## DISCLAIMER
This app relies on the private API as found [here](https://github.com/sanko/Robinhood) (special thanks to sanko for providing documentation). It isn't recommended to use this since the API is private and can change unexpectedly at any time, and is not officially supported. Using any kind of unpublished API for investing is risky, and you should thoroughly review any code involving any kind of money or investment published on the web to ensure the creator isn't doing something malicious. It's your money, after all. Your safest bet is to use the sanctioned phone app. Having said that, creating this app has been a lot of fun and I use it a lot more than I use the phone app.

## Installation
This is a basic Rails project. You can install Ruby on Rails (and RVM) by visiting [the RVM install page)[https://rvm.io/rvm/install]. If you already have ruby on rails set up, simply clone this project. Then run the basic steps to run the project like you would any other rails project:
* `bundle install`
* `bundle exec rake db:create db:migrate`
  * it doesn't actually rely on a database, but rails might complain that it isnt set up
* then, start the web server:
  * `bundle exec rails server`
* navigate to http://localhost:3000/ in whatever webrowser you use (I use chrome, for instance), and you should see a login screen:
![image](https://cloud.githubusercontent.com/assets/508449/24683768/3c277326-196f-11e7-8687-c3785c2bdd1a.png)
* Enter your log in info, and you'll be presented with your Robinhood dashboard.

### Influences and references
Thanks to Jeffrey Smith for his [designs](https://dribbble.com/shots/2619026-Robinhood-Web-App-Concept-V2) which I based a lot of the front end work off of.
Thanks to sanko for their work [documenting Robinhood's API](https://github.com/sanko/Robinhood)
