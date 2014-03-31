require 'net/http'
require 'json'

@host = 'osculate.it'
@port = '3000'

@post_ws = "/"

@json ={
    "id" => "REQUEST_CURRENT_STATE",
    "payload" => "",
  }.to_json
  
def post
     req = Net::HTTP::Post.new(@post_ws, initheader = {'Content-Type' =>'application/json'})
          req.body = @json
          response = Net::HTTP.new(@host, @port).start {|http| http.request(req) }
           puts "Response #{response.code} #{response.message}:
          #{response.body}"
        end

thepost = post
puts thepost