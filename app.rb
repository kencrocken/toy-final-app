require 'sinatra'
require 'oauth2'
require 'omniauth-google-oauth2'
require 'gmail_xoauth'
require 'json'
require 'mail'


enable :sessions

SCOPES = [
    'https://mail.google.com/',
    'https://www.googleapis.com/auth/userinfo.email'
].join(' ')

unless G_API_CLIENT = ENV['G_API_CLIENT']
  raise "You must specify the G_API_CLIENT env variable"
end

unless G_API_SECRET = ENV['G_API_SECRET']
  raise "You must specify the G_API_SECRET env veriable"
end

def client
  client ||= OAuth2::Client.new(G_API_CLIENT, G_API_SECRET, {
                :site => 'https://accounts.google.com', 
                :authorize_url => "/o/oauth2/auth", 
                :token_url => "/o/oauth2/token"
              })
end

get '/' do
  erb :index
end

get "/auth" do
  redirect client.auth_code.authorize_url(:redirect_uri => redirect_uri,:scope => SCOPES,:access_type => "offline")
end

get '/oauth2callback' do
  email_hash = {}
  @messages = []

  access_token = client.auth_code.get_token(params[:code], :redirect_uri => redirect_uri)
  session[:access_token] = access_token.token
  @message = "Successfully authenticated with the server"
  @access_token = session[:access_token]

  @address = access_token.get('https://www.googleapis.com/userinfo/email?alt=json').parsed
  @email_add = @address['data']['email']

  imap = Net::IMAP.new('imap.gmail.com', 993, usessl = true, certs = nil, verify = false)
  imap.authenticate('XOAUTH2', "#{@email_add}", session[:access_token])
  imap.select('INBOX')
  imap.search(['ALL']).each do |message_id|

    msg = imap.fetch(message_id,'RFC822')[0].attr['RFC822']
    mail = Mail.read_from_string msg

    email_hash = { from: mail.from, sent_at: mail.date.to_s, subject: mail.subject.to_s }
    @messages << email_hash
  end
  erb :success
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/oauth2callback'
  uri.query = nil
  uri.to_s
end