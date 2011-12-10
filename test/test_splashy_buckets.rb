require 'helper'

module BucketsSpecHelpers
  def fill_with_counts( a, b, c )
    a.times { |i| @buckets.add( :a, "1#{i}" ) }
    b.times { |i| @buckets.add( :b, "2#{i}" ) }
    c.times { |i| @buckets.add( :c, "3#{i}" ) }
  end
end

describe Splashy::Buckets do
  include BucketsSpecHelpers
  
  describe "failure" do
    it "fails with bad distribution" do
      assert_raises( ArgumentError ) do
        Splashy::Buckets.new( :a => 0.33, :b => 0.33, :c => 0.33 )
      end
    end
    
    it "fails with empty pool" do
      @buckets = Splashy::Buckets.new( :a => 0.33, :b => 0.33, :c => 0.34 )
      assert !@buckets.satisfied?
      assert_raises( Splashy::DistributionUnsatisfiedError ) do
        @buckets.select
      end
    end
    
    it "fails with one empty pool" do
      @buckets = Splashy::Buckets.new( :a => 0.33, :b => 0.33, :c => 0.34 )
      fill_with_counts( 0, 1, 1 )
      assert !@buckets.satisfied?
      assert_raises( Splashy::DistributionUnsatisfiedError ) do
        @buckets.select
      end
    end
    
    it "fails with not enough for the desired count" do
      @buckets = Splashy::Buckets.new({ :a => 0.33, :b => 0.33, :c => 0.34 }, 4 )
      fill_with_counts( 1, 1, 1 )
      assert !@buckets.satisfied?
      assert_raises( Splashy::DistributionUnsatisfiedError ) do
        @buckets.select
      end
    end
    
    it "fails with an empty bucket" do
      @buckets = Splashy::Buckets.new({ :a => 0.33, :b => 0.33, :c => 0.34 } )
      fill_with_counts( 1, 1, 0 )
      assert !@buckets.satisfied?
      assert_raises( Splashy::DistributionUnsatisfiedError ) do
        @buckets.select
      end
    end
    
    it "fails with distribution being such that desired count can't be met" do
      @buckets = Splashy::Buckets.new({ :a => 0.80, :b => 0.1, :c => 0.10 }, 10 )
      fill_with_counts( 2, 20, 20 )
      assert !@buckets.satisfied?
      assert_raises( Splashy::DistributionUnsatisfiedError ) do
        @buckets.select
      end
    end
    
    it "fails when trying to add to an invalid bucket" do
      @buckets = Splashy::Buckets.new({ :a => 0.80, :b => 0.2 } )
      assert_raises( ArgumentError ) do
        @buckets.add( :x, "oops" )
      end
    end
    
    it "fails with distribution being such that desired count can't be met" do
      @buckets = Splashy::Buckets.new({ :a => 0.80, :b => 0.1, :c => 0.10 } )
      fill_with_counts( 1, 2, 0 )
      assert !@buckets.satisfied?
      assert_raises( Splashy::DistributionUnsatisfiedError ) do
        @buckets.select
      end
    end
  end
  
  describe "success" do
    it "fills a single bucket, which is dumb" do
      @buckets = Splashy::Buckets.new( :a => 1 )
      @buckets.add( :a, "1" )
      assert @buckets.satisfied?
      assert_equal( {:a=>["1"]}, @buckets.select )
    end
    
    it "selects from a small pool" do
      @buckets = Splashy::Buckets.new( :a => 0.33, :b => 0.33, :c => 0.34 )
      fill_with_counts( 1, 1, 1 )
      assert @buckets.satisfied?
      assert_equal( {:a=>["10"], :b=>["20"], :c=>["30"]}, @buckets.select )
    end
    
    it "selects from a small pool with more than enough in one bucket" do
      @buckets = Splashy::Buckets.new( :a => 0.33, :b => 0.33, :c => 0.34 )
      fill_with_counts( 1, 1, 2 )
      assert @buckets.satisfied?
      assert_equal( {:a=>["10"], :b=>["20"], :c=>["30"]}, @buckets.select )
    end
    
    it "selects from a small pool with a limiter bucket" do
      @buckets = Splashy::Buckets.new( :a => 0.33, :b => 0.33, :c => 0.34 )
      fill_with_counts( 1, 3, 3 )
      assert @buckets.satisfied?
      assert_equal( {:a=>["10"], :b=>["20"], :c=>["30"]}, @buckets.select )
    end
    
    it "selects from a larger pool" do
      @buckets = Splashy::Buckets.new( :a => 0.33, :b => 0.33, :c => 0.34 )
      fill_with_counts( 3, 3, 3 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10", "11", "12"], :b=>["20", "21", "22"], :c=>["30", "31", "32"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with a unequal distribution" do
      @buckets = Splashy::Buckets.new( :a => 0.10, :b => 0.10, :c => 0.80 )
      fill_with_counts( 3, 3, 3 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10"], :b=>["20"], :c=>["30", "31"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with an \"opposite\" distribution" do
      @buckets = Splashy::Buckets.new( :a => 0.10, :b => 0.10, :c => 0.80 )
      fill_with_counts( 5, 5, 2 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10"], :b=>["20"], :c=>["30", "31"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with a skewed distribution" do
      @buckets = Splashy::Buckets.new( :a => 0.10, :b => 0.10, :c => 0.80 )
      fill_with_counts( 10, 10, 1 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10"], :b=>["20"], :c=>["30"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with another skewed distribution" do
      @buckets = Splashy::Buckets.new( :a => 0.01, :b => 0.19, :c => 0.80 )
      fill_with_counts( 10, 10, 1 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10"], :b=>["20"], :c=>["30"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with yet another skewed distribution" do
      @buckets = Splashy::Buckets.new( :a => 0.01, :b => 0.19, :c => 0.80 )
      fill_with_counts( 10, 2, 40 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10"], :b=>["20", "21"], :c=>["30", "31", "32", "33", "34", "35", "36", "37"]},
        @buckets.select
      )
    end
  end
  
  describe "filling buckets" do
    it "accepts blocks" do
      @buckets = Splashy::Buckets.new( :a => 0.01, :b => 0.19, :c => 0.80 )
      a = [[:a, "1"]]
      b = [[:b, "2"]]
      c = [[:c, "3"]]
      @buckets.fill { a.pop }
      @buckets.fill { b.pop }
      @buckets.fill { c.pop }
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["1"], :b=>["2"], :c=>["3"]},
        @buckets.select
      )
    end
    
    it "accepts blocks with specified buckets" do
      @buckets = Splashy::Buckets.new( :a => 0.01, :b => 0.19, :c => 0.80 )
      a = ["1"]
      b = ["2"]
      c = ["3"]
      @buckets.fill( :a ) { a.pop }
      @buckets.fill( :b ) { b.pop }
      @buckets.fill( :c ) { c.pop }
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["1"], :b=>["2"], :c=>["3"]},
        @buckets.select
      )
    end
  end
  
  describe "success with an enforced count" do
    it "selects from a pool with an even distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.33, :b => 0.33, :c => 0.34}, 6 )
      fill_with_counts( 10, 2, 40 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10", "11"], :b=>["20", "21"], :c=>["30", "31"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with an uneven distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.33, :b => 0.33, :c => 0.34}, 5 )
      fill_with_counts( 10, 2, 40 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>["10", "11"], :b=>["20"], :c=>["30", "31"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with a skewed distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.01, :b => 0.19, :c => 0.80}, 8 )
      fill_with_counts( 10, 2, 40 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>[], :b=>["20", "21"], :c=>["30", "31", "32", "33", "34", "35"]},
        @buckets.select
      )
    end
    
    it "selects from a pool with a wacky distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.01, :b => 0.01, :c => 0.98}, 3 )
      fill_with_counts( 3, 3, 3 )
      assert @buckets.satisfied?
      assert_equal(
        {:a=>[], :b=>[], :c=>["30", "31", "32"]},
        @buckets.select
      )
    end
  end
  
  describe "variances" do
    it "reports on a pool with an even distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.33, :b => 0.33, :c => 0.34} )
      fill_with_counts( 10, 2, 40 )
      assert_equal( [:b, :a, :c], @buckets.neediest_buckets )
    end
    
    it "reports on a pool with an uneven distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.33, :b => 0.33, :c => 0.34}, 3 )
      fill_with_counts( 10, 2, 40 )
      assert_equal( [:b, :a, :c], @buckets.neediest_buckets )
    end
    
    it "reports on a pool with a skewed distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.01, :b => 0.19, :c => 0.80} )
      fill_with_counts( 10, 2, 1 )
      assert_equal( [:c, :b, :a], @buckets.neediest_buckets )
    end
    
    it "reports on a pool with a wacky distribution" do
      @buckets = Splashy::Buckets.new( {:a => 0.01, :b => 0.01, :c => 0.98} )
      fill_with_counts( 3, 3, 3 )
      assert_equal( [:c, :a, :b], @buckets.neediest_buckets )
    end
  end
  
  describe "performance" do
    it "grows linearly with more elements" do
      puts # Formatting...
      assert_performance_linear 0.999 do |n|
        @buckets = Splashy::Buckets.new( :a => 0.20, :b => 0.30, :c => 0.50 )
        n.times do |i|
          bucket = [:a, :a, :b, :c][i % 3]
          @buckets.add( bucket, i.to_s )
        end
        @buckets.select rescue nil
      end
    end
  end
end

