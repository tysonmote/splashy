module Splashy
  private
  
  # Private: Collects elements and maintains a count.
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
    
    def random_elements( count = nil )
      if @elements.respond_to?( :sample )
        @elements.sample( count )
      else
        count ? @elements.sort_by{ rand }[0, count] : @elements.sort_by{ rand }
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
