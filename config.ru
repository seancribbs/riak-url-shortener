require 'rubygems'
require 'bundler'
Bundler.setup

require 'riak'
require 'haml'
require 'sinatra'
require 'digest/md5'

set :public, ::File.dirname(__FILE__) + '/public'
set :views, ::File.dirname(__FILE__) + '/templates'
set :haml, {:format => :html5}

# Get our Map-Reduce functions available
$map_stats = ::File.read("mapreduce/map_stats.js")
$reduce_stats = ::File.read("mapreduce/reduce_stats.js")

# Schedule the click tracking for another cycle if using EM
next_tick = lambda do |b|
  if defined?(EM)
    EM.next_tick(&b)
  else
    b.call
  end
end

# The shortcode-producing function
create_shortcode = lambda do |url|
  # 1) MD5 hash the URL to the hexdigest
  # 2) Convert it to a Bignum
  # 3) Pack it into a bitstring as a big-endian int
  # 4) base64-encode the bitstring, remove the trailing junk
  Base64.urlsafe_encode64([Digest::MD5.hexdigest(url).to_i(16)].pack("N")).sub(/==\n?$/, '')
end

get '/' do
  @message = Riak::Client.new['riak-url-shortener']['message'].raw_data rescue ''
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
  @stats_url = "#{@url}/stats"
  headers "Location" => @url
  haml :created
end

get '/:code' do
  begin
    client = Riak::Client.new
    obj = Riak::Bucket.new(client, 'urls').get(params[:code])
    url = obj.data
    next_tick.call(lambda {
                     Riak::Bucket.new(client, "clicks_#{params[:code]}").new.tap do |click|
                       click.content_type = "text/plain"
                       click.data = Time.now.to_i
                       click.store(:w => 0)
                     end
                   })
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

get '/:code/stats' do
  begin
    client = Riak::Client.new
    @object = Riak::Bucket.new(client, 'urls').get(params[:code])
    @url = "http://#{request.host_with_port}/#{@object.key}"
    @stats = Riak::MapReduce.new(client).add("clicks_#{params[:code]}").map($map_stats).reduce($reduce_stats, :keep => true).run.first
    @today = @stats[Date.today.strftime("%Y-%m-%d")] || 0
    @month = @stats[Date.today.strftime("%Y-%m")] || 0
    @year = @stats[Date.today.year.to_s] || 0
    haml(:stats)
  rescue Riak::FailedRequest => fr
    case fr.code
    when 404
      not_found(haml(:not_found))
    else
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
