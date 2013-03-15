
require 'uri'
require 'net/http'
require 'digest/md5'
require 'time'
require 'zlib'
require 'nkf'

Net::HTTP.version_1_2

class HTTPCache
  attr_reader :filename
  attr_reader :url

  def self.get(url)
    self.new(url).get
  end
  
  def initialize(url, cache_dir = "cache", prefix = "")
    @url = url
    @uri = URI.parse(@url)
    path = File.join(File.dirname(__FILE__), cache_dir)
    @filename = File.join(path, "%s%s.cache.gz" % [prefix, Digest::MD5.hexdigest(@url)])
    @lastmodified = nil
  end

  def get
    create unless valid? 
    Zlib::GzipReader.open(@filename){|io|
      return NKF.nkf('--utf8', io.read)
    }
  end

  def lastmodified
    return @lastmodified if @lastmodified
    http_start{|http|
      response = http.head(@uri.path)
      case response
      when Net::HTTPResponse
        @lastmodified = lm_time(response)
      else
        @lastmodified = Time.now
      end
    }
  end
  
private
  def valid?
    File.exist?(@filename) && (lastmodified <= File.mtime(@filename))
  end

  def http_start
    Net::HTTP.start(@uri.host, @uri.port){|http|
      yield(http)
    }
  end
  
  def lm_time(r)
    Time.httpdate(r['last-modified']) rescue Time.now
  end
  
  def create
    http_start{|http|
      response = http.get(@uri.path)
      case response
      when Net::HTTPResponse
        lm = lm_time(response)
        Zlib::GzipWriter.open(@filename, 9){|io|
          io.mtime = lm
          io.write(response.body)
        }
        File.utime(lm, lm, @filename)
      else
        raise "Unable to retrieve file: #{response.to_s}"
      end
    }
  end
end
