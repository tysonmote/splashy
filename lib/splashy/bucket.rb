module Splashy
  private
  
  # Private: Collector of elements.
  class Bucket
    attr_reader :name
    
    def initialize( name )
      @name = name
      @elements = []
    end
    
    def <<( element )
      @elements << element
    end
    
    def elements( count = nil )
      if count
        @elements[0, count]
      else
        @elements
      end
    end
    
    def empty?
      self.count == 0
    end
    
    def count
      @elements.count
    end
  end
end