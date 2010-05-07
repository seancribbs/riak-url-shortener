require 'rubygems'
# require 'bundler'
# Bundler.setup

require 'riak'
require 'haml'
require 'sinatra'
require 'digest/md5'

set :public, ::File.dirname(__FILE__) + '/public'
set :views, ::File.dirname(__FILE__) + '/templates'
set :haml, {:format => :html5}

create_shortcode = lambda do |url|
  # 1) MD5 hash the URL to the hexdigest
  # 2) Convert it to a Bignum
  # 3) Pack it into a bitstring as a big-endian int
  # 4) base64-encode the bitstring, remove the trailing junk
  Base64.urlsafe_encode64([Digest::MD5.hexdigest(url).to_i(16)].pack("N")).sub(/==\n?$/, '')
end

get '/' do
  haml :index
end

post '/' do
  client = Riak::Client.new
  key = create_shortcode.call(params[:url])
  bucket = Riak::Bucket.new(client, 'urls')
  Riak::RObject.new(bucket, key).tap do |obj|
    obj.content_type = "text/plain"
    obj.data = params[:url]
    obj.store
  end
  status 201
  @url = "http://#{request.host_with_port}/#{key}"
  headers "Location" => @url
  haml :created
end

get '/:code' do
  begin
    client = Riak::Client.new
    obj = Riak::Bucket.new(client, 'urls').get(params[:code])
    url = obj.data
    halt 301, {"Location" => url}, []
  rescue Riak::FailedRequest => fr
    case fr.code
    when 404
      not_found(haml(:not_found))
    when 500..599
      error(503, haml(:error))
    end
  end
end

not_found do
  haml :not_found
end

error do
  haml :error
end

run Sinatra::Application
