module Splashy
  class Buckets
    # wanted_distribution - A Hash of desired distributions:
    #                       { :a => 0.2, :b => 0.5, :c => 0.3 }
    # wanted_count        - (optional) Maximum total elements to be selected.
    #                       otherwise, the maximum size set is selected.
    def initialize( wanted_distribution, wanted_count=nil )
      unless wanted_distribution.values.inject(0){ |m,v| m + v } == 1.0
        raise ArgumentError.new( "Distribution must sum to 1.0" )
      end
      @wanted_distribution = wanted_distribution
      @wanted_count = wanted_count
      @buckets = {}
      @wanted_distribution.keys.each do |bucket_name|
        @buckets[bucket_name] = Bucket.new( bucket_name )
      end
      @total_count = 0
    end
    
    # Public: Put elements into buckets with a block.
    # 
    # bucket_name - If supplied, all yielded elements will be added to that
    #               bucket.
    # &block - A block that returns (if `bucket_name` is not supplied) an
    #          Array: [bucket_name, element]. If `bucket_name` is supplied, only
    #          the element needs to be returned.
    # 
    # Examples
    # 
    #   fill { return [bucket_name, element] }
    #   fill( :bucket_name ) { return element }
    def fill( bucket_name = nil, &block )
      if bucket_name
        while element = yield( @total_count )
          self.add( bucket_name, element )
        end
      else
        while pair = yield( @total_count )
          self.add( *pair )
        end
      end
    end
    
    # Public: Add a single element to a bucket.
    def add( bucket_name, element )
      unless @wanted_distribution[bucket_name]
        raise ArgumentError.new( "#{bucket_name.inspect} is not a valid bucket." )
      end
      @buckets[bucket_name] << element
      @total_count += 1
    end
    
    # Public
    # 
    # Returns true if the conditions (distribution and, optionally, count) are
    # satisfied enough to do a final selection of elements.
    def satisfied?
      begin
        self.assert_satisfied!
        true
      rescue DistributionUnsatisfiedError => e
        false
      end
    end
    
    # Public: Return a distribution of elements based on the desired
    # distribution. If a satisfactory distribution is not possible, a
    # DistributionUnsatisfiedError is raised.
    # 
    # Returns a Hash of elements matching the desired distribution, keyed by
    # the bucket names.
    def select( opts = {} )
      self.assert_satisfied!
      opts = { :random => false }.merge( opts )
      
      selected = self._select_wanted( opts[:random] )
      
      # Sometimes we need to fudge by a few to meet the `@wanted_count`
      selected = self.trim( selected, @wanted_count ) if @wanted_count
      selected
    end
    
    # Array of the buckets that need more elements to match the desired
    # distribution, sorted descending by how much more they need.
    def neediest_buckets
      multipliers = self.needed_multipliers( self._select_all, @wanted_distribution ).to_a
      multipliers.sort! { |a, b| b[1] <=> a[1] } # Sort on multiplier ascending
      multipliers.map{ |bucket_name, multiplier| bucket_name }
    end
    
    protected
    
    # Protected
    # 
    # Returns Hash of all bucket elements, keyed by bucket name.
    def _select_all
      @buckets.values.inject({}) do |memo, bucket|
        memo[bucket.name] = bucket.elements
        memo
      end
    end
    
    # Protected
    # 
    # Returns Hash of bucket elements, matching the wanted distribution as
    # closely as possible.
    def _select_wanted( randomly = false )
      final_count = self.estimated_final_count
      
      @buckets.values.inject({}) do |memo, bucket|
        count = ( final_count * @wanted_distribution[bucket.name] ).round
        count = [1, count].max # Ensure every bucket has at least one element
        if randomly
          memo[bucket.name] = bucket.random_elements( count )
        else
          memo[bucket.name] = bucket.elements( count )
        end
        memo
      end
    end
    
    # Protected: Trim a given Hash of Arrays -- keyed by bucket names -- until
    # it satisfies @wanted_count.
    # 
    # selected - A Hash of selected elements, keyed by the bucket names. All
    #            values must be Arrays (or respond to `size`).
    # size - The desired total size of `selected`.
    def trim( selected, size )
      raise ArgumentError.new( "Can't trim to a nil size" ) unless size
      while self.class.elements_count( selected ) > size
        candidates = self.trim_candidates( selected, @wanted_distribution )
        selected[candidates.first].pop
      end
      
      selected
    end
    
    # Protected
    # 
    # current_selections - Hash of element Arrays, keyed by bucket name.
    # wanted_distribution - The wanted distribution as a hash of percentage
    #                       Floats.
    # 
    # Returns Array of bucket names for buckets that are good trim candidates,
    # ordered by best candidates first.
    def trim_candidates( current_selections, wanted_distribution )
      multipliers = self.needed_multipliers( current_selections, wanted_distribution ).to_a
      multipliers.select do |bucket_name, multiplier|
        # Can't trim empty buckets
        @buckets[bucket_name].count != 0
      end
      return multipliers if multipliers.empty?
      multipliers.sort! { |a, b| a[1] <=> b[1] } # Sort on multiplier ascending
      multipliers.map{ |bucket_name, multiplier| bucket_name }
    end
    
    # Protected
    # 
    # current_selections - Hash of element Arrays, keyed by bucket name.
    # wanted_distribution - The wanted distribution as a hash of percentage
    #                       Floats.
    # 
    # Returns Hash of multipliers needd for each bucket to reach its current
    # wanted distribution.
    def needed_multipliers( current_selections, wanted_distribution )
      total_size = self.class.elements_count( current_selections )
      
      current_selections.keys.inject({}) do |memo, bucket_name|
        bucket_size = current_selections[bucket_name].size
        desired_pct = wanted_distribution[bucket_name]
        current_pct = bucket_size.to_f / total_size
        if current_pct > 0
          memo[bucket_name] = desired_pct / current_pct
        else
          memo[bucket_name] = 1 / 0.0 # Infinity
        end
        memo
      end
    end
    
    # Protected
    # 
    # hash - Hash of Objects that respond to `count` (usually Arrays).
    # 
    # Returns count of all elements in the Hash's Array values.
    def self.elements_count( hash )
      hash.values.inject(0){ |memo, array| memo + array.count }
    end
    
    # Protected
    # 
    # Returns projected final number of elements that will be returned to
    # satisfy the requirements. If this is less than `@wanted_count`, if
    # supplied, we can't meet the requirements.
    def estimated_final_count
      limiter_bucket = self.limiter_bucket
      final_count = ( limiter_bucket.count / @wanted_distribution[limiter_bucket.name] ).floor
      final_count = [@wanted_count, final_count].min if @wanted_count
      final_count
    end
    
    # Protected
    # 
    # Raises a DistributionUnsatisfiedError if we can't meet the wanted
    # distribution or count (or both).
    def assert_satisfied!
      if @total_count < @wanted_distribution.size
        raise DistributionUnsatisfiedError.new(
          "Not enough elements (#{@total_count})."
        )
      end
      
      empty_buckets = @buckets.keys.select{ |name| @buckets[name].empty? }
      unless empty_buckets.empty?
        raise DistributionUnsatisfiedError.new(
          "The following buckets are empty: #{empty_buckets.map{|b| b}.join(', ')}."
        )
      end
      
      if @wanted_count
        if @total_count < @wanted_count
          raise DistributionUnsatisfiedError.new(
            "Not enough elements (#{@total_count}) to satisfy your desired count (#{@wanted_count})."
          )
        end
        
        if self.estimated_final_count < @wanted_count
          raise DistributionUnsatisfiedError.new(
            "Distribution prevents the satisfaction of your desired count (#{@wanted_count})."
          )
        end
      end
    end
    
    # Protected
    # 
    # Return the Bucket that is the current limiter in the distribution. In
    # other words, this bucket is limiting the total size of the final
    # selection.
    def limiter_bucket
      # Smallest value of "count / desired percent" is the limiter.
      @buckets.values.map do |bucket|
        [bucket, bucket.count / @wanted_distribution[bucket.name]]
      end.sort { |a, b| a[1] <=> b[1] }[0][0]
    end
  end
end
