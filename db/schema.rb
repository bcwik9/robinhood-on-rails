# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170424021948) do

  create_table "instruments", force: :cascade do |t|
    t.string   "url"
    t.string   "symbol"
    t.string   "quote_url"
    t.string   "fundamentals_url"
    t.string   "robinhood_id"
    t.string   "name"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  create_table "robinhood_accounts", force: :cascade do |t|
    t.string   "account_number"
    t.integer  "robinhood_user_id"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  create_table "robinhood_users", force: :cascade do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.string   "username"
    t.string   "email"
    t.string   "robinhood_id"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "stock_lists", force: :cascade do |t|
    t.string   "name"
    t.integer  "robinhood_account_id"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.string   "group"
  end

end
