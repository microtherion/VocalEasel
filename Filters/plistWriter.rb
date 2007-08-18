#
# plistWriter - Write ruby object as Apple plist
#

require 'rexml/document'
require 'base64'

class PlistData
  def initialize(string)
    @str = string
  end

  def to_s
    return @str
  end
end

def _encodePlist(object)
  e = nil
  case object 
  when String then
    e = REXML::Element.new("string")
    e.add_text(object)
  when PlistData then
    e = REXML::Element.new("data")
    e.add_text(object.to_s)
  when Integer then
    e = REXML::Element.new("integer")
    e.add_text(object.to_s)
  when Float then
    e = REXML::Element.new("real")
    e.add_text(object.to_s)
  when Time then
    e = REXML::Element.new("date")
    e.add_text(object.utc.xmlschema)
  when Array then
    e = REXML::Element.new("array")
    object.each do |elt|
      e.add_element(_encodePlist(elt))
    end
  when Hash then
    e = REXML::Element.new("dict")
    object.each do |key,elt|
      k = REXML::Element.new("key")
      k.add_text(key)
      e.add_element(k)
      e.add_element(_encodePlist(elt))
    end
  else
    raise "plistWriter can't encode objects of type `#{object.class}'[#{object.class.id}]"
  end

  return e
end

def writePlist(destination, object)
  doc = REXML::Document.new
  doc.add REXML::XMLDecl.new("1.0", "UTF-8")
  doc.add REXML::DocType.new(["plist", "PUBLIC", 
                              "\"-//Apple//DTD PLIST 1.0//EN\"",
                              "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\""])
  contents = REXML::Element.new("plist")
  contents.add_attribute("version", "1.0")
  contents.add_element(_encodePlist(object))

  doc.add_element(contents)
  doc.write(destination, 4)
end
