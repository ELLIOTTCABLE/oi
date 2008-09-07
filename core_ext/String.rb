class String
  # Translate a four-character code to some numeric value apparently used
  # internally in some way by OS X.
  def to_fcc
    raise "#{self} is #{self.length} characters - only four-character strings can be four-character encoded... duh" unless
      self.length == 4
    self.unpack('N').first
  end
end
