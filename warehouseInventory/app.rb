# app.rb

require "sinatra"
require "sinatra/activerecord"
require "./models"

#require "mysql2"
#set :database, "mysql2://root:root@localhost:3306/whdb"

set :database, "sqlite3:myblogdb.sqlite3"


before do
  #Browser Accessible
  # headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
  headers['Access-Control-Allow-Methods'] = 'POST'
  headers['Access-Control-Allow-Origin'] = 'http://localhost:4567'
  headers['Access-Control-Allow-Headers'] = 'accept, authorization, origin'
  headers['Access-Control-Allow-Credentials'] = 'true'
end

# index
get '/' do
  send_file './public/index.html'
end

#signin for developers
# /? is used for with or without / at end
get '/signin/?' do
  erb :signin, locals: {title: 'Sign In'}
end
#signin for developers
get '/signin1/?' do
  erb :signin1, locals: {title: 'Sign In'}
end

# singup users
post '/signin' do
  @user = User.where(username: params[:username])
  if @user.present?
    @message = 'User name exist'
    @user = nil
  else
    @user = User.create(username: params[:username], password: params[:password], seller_id: params[:sellerid])
    @user = User.find(@user.id)
  end
  erb :signup
end

# login users
post '/login' do
  @user = User.where(username: params[:username], seller_id: params[:sellerid])
  #check password
  if @user.present?

    @user.each do |u|
      if u.password == params[:password]
        @user = User.find(u.id)
      end
    end
  else
    @message = 'Please sign up as developer to create an account.'
  end
  erb :signup
end

# List of inventory
get '/api/inventory/?' do
  puts env['HTTP_ORIGIN']
  # content_type :json
  @user = User.where(token: env['HTTP_TOKEN'])
  if @user.present?
    @user.each do |user|
      @sku = Sku.where(seller_id: user.seller_id)
    end
  else
    @message = 'Invalid Token. Request the token from developer site.'
  end
  erb :skuresult
end

# inventory search SKU item
get '/api/inventory/:item' do
  # using like operator
  # @skus = Sku.search(params[:name])

  @user = User.where(token: env['HTTP_TOKEN'])
  if @user.present?
    @user.each do |user|
      @sku = Sku.where("item = ? and seller_id = ? ", params[:item], user.seller_id)
    end
    @message = 'There are no SKU matching the item(s)'+ params[:item] if @sku.blank?
  else
    @message = 'Invalid Token. Request the token from developer site.'
  end
  erb :skuresult
end

# List of user
post '/users' do
  content_type :json
  @user = User.all.to_json
end

# user notify update
put '/users/:id/:notify' do
  @user = User.find(params[:id])
  @user.update(notify: params[:notify])
  @user.save
  # redirect '/user/'+params[:id]
  erb :signup
end

# delete user
delete '/user/:id' do
  @user = User.find(params[:id])
  @user.destroy
  erb :delete
end

# Inventory Replenishment
post '/api/inventory/?' do
  if env['HTTP_ORIGIN'] == 'http://localhost:4567'
    @user = User.where(token: env['HTTP_TOKEN'])
    if @user.present?
      @user.each do |user|
        @sku = Sku.where("item = ? and seller_id = ? and status ='Shipped'", params[:item], user.seller_id)
        if @sku.blank?
          Sku.create(item: params[:item], quantity: 0, status: 'Shipped', seller_id: user.seller_id)
          @sku = Sku.where("item = ? and seller_id = ? and status ='Shipped'", params[:item], user.seller_id)
        end
      end
      @message = 'There are no SKU matching the item(s)'+ params[:item] if @sku.blank?
      @sku.each do |sku|
        if sku.quantity.to_i <= params[:qty].to_i
          @message = 'There is no space to store your inventory replenishment. There are only ' + sku.quantity.to_s + ' spots available.'
        end
      end
    else
      @message = 'Invalid Token. Request the token from developer site.'
    end
  else
    @message = 'This is not browser accessible. Must access from same domain.'
  end
  erb :skuresult
end

#Place Order for Shipment
post '/api/orders/?' do
  if env['HTTP_ORIGIN'] == 'http://localhost:4567'
    @user = User.where(token: env['HTTP_TOKEN'])
    @userId = ""
    if @user.present?
      @user.each do |user|
        @userId = user.seller_id
        @sku = Sku.where("item = ? and seller_id = ? and status ='In Stock'", params[:item], user.seller_id)
        @sku1 = Sku.where("item = ? and seller_id = ? and status ='Preparing for Shipment'", params[:item], user.seller_id)
        if @sku1.blank?
          Sku.create(item: params[:item], quantity: 0, status: 'Preparing for Shipment', seller_id: user.seller_id)
        end

        @sku1 = Sku.where("item = ? and seller_id = ? and status ='Preparing for Shipment'", params[:item], user.seller_id)

      end
      @message = 'There are no SKU matching the item(s)'+ params[:item] if @sku.blank?
      @sku.each do |sku|
        if sku.quantity.to_i >= params[:qty].to_i
          x = sku.quantity.to_i - params[:qty].to_i
          @sku.update(quantity: x)
          @message = 'Your order with '+ params[:qty]+' to '+params[:address]+' is preparing for shipment.'
          @sku1.each do |sku1|
            y = sku1.quantity.to_i + params[:qty].to_i
            @sku1.update(quantity: y)
          end

          @order = Order.create(item: params[:item], quantity: params[:qty], address: params[:address], seller_id: @userId)
        else
          @message = 'Your order not successful. There are only ' + sku.quantity.to_s + ' in stock. You tried to order ' + params[:qty].to_s + '.'
        end
      end
    else
      @message = 'Invalid Token. Request the token from developer site.'
    end
  else
    @message = 'This is not browser accessible.'
  end
  @sku = Sku.where("item = ?", params[:item])
  erb :skuresult
end

after do
  # Close the connection after the request is done so that we don't
  # deplete the ActiveRecord connection pool.
  ActiveRecord::Base.connection.close
end
