# Robinhood on Rails
Robinhood on Rails is a simple front end dashboard for the free trading platform [Robinhood](https://robinhood.com/referral/benjamc331/). You're presented with your autorefreshing portfolio after logging in:
![image](http://imgur.com/xARMfno.png)

### Current Features (work in progress)
- Auto refreshing dashboard
- Price charts
- Orders
  - Buy
  - Sell
- Transfers
  - Deposit
  - Withdraw
- Dividends
- View/Dismiss Notifications

## DISCLAIMER
I am not affiliated with Robinhood or its associates. I am in no way responsible for any losses incurred through using this code or application. This app relies on the private API as found [here](https://github.com/sanko/Robinhood) (special thanks to sanko for providing documentation). It isn't recommended to use this since the API is private and can change unexpectedly at any time, and is not officially supported. Using any kind of unpublished API for investing is risky, and you should thoroughly review any code involving any kind of money or investment published on the web to ensure the creator isn't doing something malicious. It's your money, after all. Your safest bet is to use the sanctioned phone app. Having said that, creating this app has been a lot of fun and I use it a lot more than I use the phone app.

## Usage
This repository comes with a Dockerfile to easily set up a server with minimal configuration. To build the image, run:

```shell
$ git clone https://github.com/bcwik9/robinhood-on-rails.git
$ cd robinhood-on-rails
$ docker build --tag robinhood-on-rails .
```

Then you can run the server:
```shell
$ docker run --rm -dt -p 3000:3000 robinhood-on-rails
```

This will run the server on your host-machine's port 3000.

## Installation
This is a basic Rails project. You can install Ruby on Rails (and RVM) by visiting [the RVM install page](https://rvm.io/rvm/install). If you already have ruby on rails set up, simply clone this project. Then run the basic steps to run the project like you would any other rails project:
* `bundle install`
* `bundle exec rake db:create db:migrate`
  * it doesn't actually rely on a database, but rails might complain that it isnt set up
* then, start the web server:
  * `bundle exec rails server`
* navigate to http://localhost:3000/ in whatever webrowser you use (I use chrome, for instance), and you should see a login screen:
![image](https://cloud.githubusercontent.com/assets/508449/24683768/3c277326-196f-11e7-8687-c3785c2bdd1a.png)
* Enter your log in info, and you'll be presented with your Robinhood dashboard.

### Who am I
I am not affiliated with Robinhood or any of its associates. This is just a project I find fun. More info at [bencwik.com](http://bencwik.com)

### Influences and references
Thanks to Jeffrey Smith for his [designs](https://dribbble.com/shots/2619026-Robinhood-Web-App-Concept-V2) which I based a lot of the front end work off of.
Thanks to sanko for their work [documenting Robinhood's API](https://github.com/sanko/Robinhood)
