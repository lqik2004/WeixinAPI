require 'rubygems'
require 'digest/sha1'
require 'net/http'
require 'grape'
require 'active_support/core_ext'
require 'rack'

#Token Value
Token = 'mobwifi'

class WeiXinWifiAPI < Grape::API
  version 'v1', :using => :path
  format :xml
  content_type :xml, "text/xml"

  helpers do
    def checksignature(signature, timestamp, nonce)
      array = [::Token, timestamp, nonce].sort
      signature == Digest::SHA1.hexdigest(array.join)
    end

    # 根据google经纬度返回baidu经纬度
    # # return [lng_b, lat_b]
    def get_baidu_lat_lng(lat_g, lng_g)
      baidu_api_url = URI("http://api.map.baidu.com/ag/coord/convert?from=2&to=4&x=#{lng_g}&y=#{lat_g}")
      result = Net::HTTP.get(baidu_api_url)
      # 获取百度经纬度，去掉多余部分并Base64解码
      JSON.parse(result).delete_if {|k, v| k == 'error' }.map {|k,v| Base64.decode64(v)}
    end
  end

  desc "test"
  get '/test' do
    {:a => 1}.to_xml
  end

  desc "validation"
  get do
    if checksignature(params[:signature], params[:timestamp], params[:nonce])
      params[:echostr]
    end
  end

  desc "reply"
  post do
    body = Hash.from_xml(request.body.read)
    status("200")
    case body['xml']['MsgType']
    when "text"
      reply = body['xml']['Content']
    when "location"
      local_array = get_baidu_lat_lng([body['xml']['Location_X'], body['xml']['Location_Yl']])
      #TODO 
      #reply = local_array.join(", ")
    end
    builder = Nokogiri::XML::Builder.new do |x|
      x.xml() {
        x.ToUserName {
          x.cdata body['xml']['FromUserName']
        }
        x.FromUserName {
          x.cdata body['xml']['ToUserName']
        }
        x.CreateTime Time.now.to_i.to_s
        x.MsgType {
          x.cdata "text"
        }
        x.Content {
          x.cdata reply
        }
        x.FuncFlag("0")
      }
    end
  end
end

run ::WeiXinWifiAPI

# 执行方式 rackup api.ru -p 8888
# 请求链接 http://localhost:8888/v1/test
