require 'sinatra'
require 'sinatra/streaming'
require 'oauth'
require 'readit'
require 'read_it_later'
require 'haml'
require 'json'

enable :sessions
set :haml, :format => :html5

# CONFIG START
RIL_KEY = ENV['RIL_KEY']
RD_KEY = ENV['RD_KEY']
RD_SECRET = ENV['RD_SECRET']

if ENV['RACK_ENV'] == 'development'
	HOST_CALLBACK = "http://localhost:3000/auth/callback"
else
	HOST_CALLBACK = "http://readability-importer.heroku.com/auth/callback"
end
# CONFIG END

get '/' do
	session.clear
	haml :index
end

get '/auth/callback' do
	if params[:oauth_verifier].nil?
		'Looks like you denied us access. Halting. <a href="/">Try again</a>'
	else
		@request_token = session[:request_token]
		@access_token = @request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])
		session[:access_token] = @access_token

		# grab article count from readability
		Readit::Config.consumer_key = RD_KEY
		Readit::Config.consumer_secret = RD_SECRET
		@api = Readit::API.new @access_token.token, @access_token.secret
		page = 1
		bookmarks = []
		while new_bookmarks = @api.bookmarks(:page => page)
			bookmarks += new_bookmarks
			page = page + 1
		end
		
		ril_user = ReadItLater::User.new(session[:ril_username], session[:ril_password])
	  	ril = ReadItLater.new(RIL_KEY)
	  	ril_response = ril.auth(ril_user)
	  	if ril_response[:status] != 200
	  		'Oops, your ReadItLater credentials are no good. Halting. <a href="/">Try again</a>'
	  	else
	  		ril_articles = ril.get(ril_user, {:state => :unread})
	  		url_json = JSON.parse(ril_articles[:text])

	  		haml :auth, :locals => { 
	  			:ril_article_count => url_json['list'].count,
	  			:readability_article_count => bookmarks.count
  			}
		end		
	end
end

get '/go' do
	@access_token = session[:access_token]
	if @access_token.nil?
		"Oops, we have no login information for you. <a href=\"/\">Go Home</a>"
	else
		Readit::Config.consumer_key = RD_KEY
		Readit::Config.consumer_secret = RD_SECRET
		@api = Readit::API.new @access_token.token, @access_token.secret
		ril_user = ReadItLater::User.new(session[:ril_username], session[:ril_password])
	  	ril = ReadItLater.new(RIL_KEY)
	  	ril_response = ril.auth(ril_user)
	  	if ril_response[:status] != 200
	  		'Oops, your ReadItLater credentials are no good. Halting. <a href="/">Try again</a>'
	  	else
	  		ril_articles = ril.get(ril_user, {:state => :unread})
	  		url_json = JSON.parse(ril_articles[:text])
	  		url_list = []

	  		stream(:keep_open) do |out|
		  		url_json['list'].to_a.reverse.each do |key,value|
		  			out.puts "Adding #{value['url']} <br />"
		  			out.flush
		  			@api.bookmark :url => value['url']
		  		end
				session.clear
				out.puts "Okay, #{@api.me.username}, I sent #{url_json['list'].count} URLs to Readability. Enjoy."
				out.flush
	  		end
		end
	end
end

get '/delete' do
	@access_token = session[:access_token]
	if @access_token.nil?
		"Oops, we have no login information for you. <a href=\"/\">Go Home</a>"
	else
		Readit::Config.consumer_key = RD_KEY
		Readit::Config.consumer_secret = RD_SECRET
		@api = Readit::API.new @access_token.token, @access_token.secret

		# now, delete all the bookmarks
		page = 1
		bookmarks = []
		while new_bookmarks = @api.bookmarks(:page => page)
			bookmarks += new_bookmarks
			page = page + 1
		end

		bookmark_count = bookmarks.count
  		stream(:keep_open) do |out|
			bookmarks.each do |b| 
				out.puts "Deleting ID #{b.id}<br/>"
				out.flush
				p "#{b.id}"
				@api.delete_bookmark(b.id)
			end
			session.clear
			out << "Okay, I deleted #{bookmark_count} bookmarks from your Readability account.<br /><a href=\"/\">Go Home</a>."
  		end
	end
end


post '/auth' do
	# test for readitlater credentials
	ril_user = ReadItLater::User.new(params[:username], params[:password])
  	ril = ReadItLater.new(RIL_KEY)

	ril_response = ril.auth(ril_user)
	if ril_response[:status] != 200
		redirect '/'
	end

	session.clear
	session[:ril_username] = params[:username]
	session[:ril_password] = params[:password]

	# oauth with readability
	@callback_url = HOST_CALLBACK
	@consumer = OAuth::Consumer.new(RD_KEY, RD_SECRET,
		{
			:site => "https://www.readability.com", 
			:authorize_path=>"/api/rest/v1/oauth/authorize/", 
			:access_token_path => "/api/rest/v1/oauth/access_token/", 
			:request_token_path=>"/api/rest/v1/oauth/request_token/"
		})
	@request_token = @consumer.get_request_token(:oauth_callback => @callback_url)
	session[:request_token] = @request_token
	redirect @request_token.authorize_url(:oauth_callback => @callback_url)
end
