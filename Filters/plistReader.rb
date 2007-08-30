#
# plistReader - Read apple plist into ruby object
#

require 'rexml/document'
require 'rexml/streamlistener'
require 'base64'
require 'date'
require 'time'

class PlistListener
  include REXML::StreamListener

  def initialize
    @stack  = []
    @kstack = []
    @vessel = nil
    @obj    = nil
    @key    = nil
    @kind   = nil
  end

  def rootObject 
    return @obj
  end

  def tag_start(tag, attrs)
    case tag
    when "array" then
      @stack.push(@vessel = [])
      @kstack.push(@key)
      @key = nil
    when "dict" then
      @stack.push(@vessel = {})
      @kstack.push(@key)
      @key = nil
    when "string", "integer", "real", "data", "date", "key" then
      @kind = tag
      @obj  = ""
    when "true" then
      @obj = true
    when "false" then
      @obj = false
    end
  end

  def text(text)
    case @kind
    when "string", "key" then
      @obj += text
    when "data" then
      @obj = Base64.decode(text)
    when "date" then
      @obj = Time.xmlschema(text)
    when "integer" then
      @obj = text.to_i
    when "real" then
      @obj = text.to_f
    end
  end

  def tag_end(tag)
    @kind = nil
    case tag
    when "array", "dict" then
      @obj    = @stack.pop
      @key    = @kstack.pop
      @vessel = @stack.last
    when "key" then
      @key = @obj
      @obj = nil
    end
    if @vessel && @obj then
      if @key then
        @vessel[@key] = @obj
        @key = nil
      else
        @vessel.push(@obj)
      end
    end
  end
end

def readPlist(source)
  listener = PlistListener.new
  REXML::Document.parse_stream(source, listener)
  listener.rootObject
end
