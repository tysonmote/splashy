module Splashy
  VERSION = "0.0.1"
  
  # That's unpossible!
  class DistributionUnsatisfiedError < StandardError; end
end

require "splashy/buckets"
require "splashy/bucket"
