module RailsStuff
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 4
    TINY  = 0
    PRE   = nil

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end
end
