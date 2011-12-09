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
    
    # Public: Put elements into buckets.
    # 
    # bucket_name - If supplied, all yielded elements will be added to that
    #               bucket.
    # &block      - A block that returns (if `bucket_name` is not supplied)
    #               an Array: [bucket_name, element]. If `bucket_name` is
    #               supplied, only the element needs to be returned.
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
    
    # Returns true if the conditions are satisfied enough to select.
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
    # Returns a Hash of elements based on the desired distribution, keyed by
    # the bucket names.
    def select
      self.assert_satisfied!
      
      total_count = estimated_final_count
      
      selected = @wanted_distribution.keys.inject({}) do |memo, bucket_name|
        bucket = @buckets[bucket_name]
        count = total_count * @wanted_distribution[bucket_name]
        count = [1, count.round].max
        memo[bucket_name] = bucket.elements( count )
        memo
      end
      
      # Sometimes we need to fudge by a few to meet the `@wanted_count`
      selected = self.trim( selected ) if @wanted_count
      
      selected
    end
    
    protected
    
    # Trim a given Hash of Arrays keyed by bucket names until it meets
    # @wanted_count.
    def trim( selected )
      raise ArgumentError.new( "Can't trip to a nil @wanted_count" ) unless @wanted_count
      
      while self.class.elements_count( selected ) > @wanted_count
        # Calculate current variances from desired distribution. Ignore
        # buckets with only one element, too.
        variances = selected.keys.inject([]) do |memo, bucket_name|
          size = selected[bucket_name].size
          if size > 1
            current_percent = size / @wanted_count.to_f
            variance = @wanted_distribution[bucket_name] / current_percent
            memo << [bucket_name, variance]
          end
          memo
        end
        break if variances.empty? # All have one element. Can't trim.
        trim_bucket_name = variances.sort{ |a, b| a[1] }[0][0] # Smallest variance
        selected[trim_bucket_name].pop
      end
      
      selected
    end
    
    # Returns count of all elements in the Hash's Array values.
    def self.elements_count( hash )
      hash.values.inject(0){ |memo, array| memo + array.count }
    end
    
    # Returns projected final number of elements that will be returned to
    # satisfy the requirements. If this is less than `@wanted_count`, when
    # supplied, we can't meet the requirements.
    def estimated_final_count
      limiter_bucket = self.limiter_bucket
      final_count = ( limiter_bucket.count / @wanted_distribution[limiter_bucket.name] ).floor
      final_count = [@wanted_count, final_count].min if @wanted_count
      final_count
    end
    
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
    
    # Return the bucket that is the limiter in the distribution.
    def limiter_bucket
      # Smallest value of "count / desired percent" is the limiter.
      @buckets.values.map do |bucket|
        [bucket, bucket.count / @wanted_distribution[bucket.name]]
      end.sort { |a, b| a[1] <=> b[1] }[0][0]
    end
  end
end
