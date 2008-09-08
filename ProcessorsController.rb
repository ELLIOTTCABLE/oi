require 'cgi'
# This class controls the active processors, and the window used to edit them.
class ProcessorsController < OSX::NSArrayController
  # This is run once the NIB is loaded - i.e. when the application has
  # completed starting.
  def awakeFromNib
    registerUriHook
  end
  
  # This registers the +getUri_withReplyEvent+ method with OS X as the proper
  # hook for those URI schemes that Info.plist defines this app as being able
  # to handle.
  def registerUriHook
    OSX::NSAppleEventManager.sharedAppleEventManager.
      setEventHandler_andSelector_forEventClass_andEventID_(
        self, :getUri_withReplyEvent, 'GURL'.to_fcc, 'GURL'.to_fcc)
  end
  
  # This hook passes incoming URIs to a processor.
  def getUri_withReplyEvent(event, reply)
    uri = event.paramDescriptorForKeyword('----'.to_fcc).stringValue
    dest = process(uri)
    `open '#{dest}'` if dest
  end
  
  # This will 
  def process(uri)
    uri = uri.to_ruby # Can't do much with the shit RubyCocoa gives us
    uri = uri.gsub /^\w+:/, '' # Get rid of the protocol
    protocol = ( bits = uri.split('/') ).shift
    bits.map {|bit| CGI.escape bit }
    all_bits = bits.clone
    processor = getProcessor(protocol).to_ruby # Ditto about RubyCocoa
    return false if ( processor ).nil?
    
    processor.gsub /\%(?!\%)(.)/ do
      case $1
      when /\d/ # Returns a specific bit, and eats it
        bits.delete_at($1.to_i)
      when '*' # All bits, even eaten ones
        all_bits.join('/')
      when '$' # All bits not yet eaten by a $<n>, joined by the original seperator
        bits.join('/')
      else
        raise "'#{$1}' is not a valid control sequence"
      end
    end
  end
  
  # For now, we'll hardcode in 'search' as the key
  def getProcessor(key)
    key.downcase!
    raise ArgumentError, 'key must be a string' unless key.match /^[a-z]+$/
    
    context = OSX::NSApp.delegate.managedObjectContext
    request = OSX::NSFetchRequest.alloc.init
    
    entity = OSX::NSEntityDescription.
      entityForName_inManagedObjectContext('Processor', context)
    request.setEntity(entity)
    
    predicate = OSX::NSPredicate.predicateWithFormat("(key LIKE[c] '#{key}')")
    request.setPredicate(predicate)
    
    sortDescriptor = OSX::NSSortDescriptor.alloc.initWithKey_ascending('key', true)
    request.setSortDescriptors([sortDescriptor])
    
    result = context.executeFetchRequest_error(request).first
    if result.is_a? OSX::NSError
      OSX::NSLog("Error Retriving Data: %@", result)
      return nil
    end
    OSX::NSLog("Item: %@ Class: %@", result, result.class)
    result = result.to_ruby # can't call #empty? or #size or #[] on a NSCFArray
    return nil if result.empty?
    return result.first.valueForKey('uri')
  end
end