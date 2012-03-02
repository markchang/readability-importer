require 'sinatra'
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
HOST_CALLBACK = "http://readability-importer.heroku.com/auth/callback"
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

		ril_user = ReadItLater::User.new(session[:ril_username], session[:ril_password])
	  	ril = ReadItLater.new(RIL_KEY)
	  	ril_response = ril.auth(ril_user)
	  	if ril_response[:status] != 200
	  		'Oops, your ReadItLater credentials are no good. Halting. <a href="/">Try again</a>'
	  	else
	  		ril_articles = ril.get(ril_user, {:state => :unread})
	  		url_json = JSON.parse(ril_articles[:text])
	  		haml :auth, :locals => { :article_count => url_json['list'].count }
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
	  		url_json['list'].map {|key,value| @api.bookmark :url => value['url']}
			session.clear
			"Okay, #{@api.me.username}, I sent #{url_json['list'].count} URLs to Readability. Enjoy."
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
