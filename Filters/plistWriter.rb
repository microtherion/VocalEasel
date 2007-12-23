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

def _encodePlist(destination, object, indent)
  destination.print " "*indent
  case object 
  when false then
    destination.print "<false/>\n"
  when true then
    destination.print "<true/>\n"
  when String then
    destination.print "<string>#{object}</string>\n"
  when PlistData then
    destination.print "<data>#{object}</data>\n"
  when Integer then
    destination.print "<integer>#{object}</integer>\n"
  when Float then
    destination.print "<real>#{object}</real>\n"
  when Time then
    destination.print "<date>#{object.utc.xmlschema}</date>\n"
  when Array then
    destination.print "<array>\n"
    object.each do |elt|
      _encodePlist(destination, elt, indent+2)
    end
    destination.print "#{" "*indent}</array>\n"
  when Hash then
    destination.print "<dict>\n"
    object.keys.sort.each do |key|
      destination.print "#{" "*indent}  <key>#{key}</key>\n"
      _encodePlist(destination, object[key], indent+2)
    end
    destination.print "#{" "*indent}</dict>\n"
  else
    raise "plistWriter can't encode objects of type `#{object.class}'"
  end
end

def writePlist(destination, object)
  destination.print <<'HEADER'
<?xml version='1.0' encoding='UTF-8'?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version='1.0'>
HEADER

  _encodePlist(destination, object, 2)

  destination.print "</plist>\n"
end
