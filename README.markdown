Splashy
=======

Simple distribution-based sampling of arbitrary objects from pools. Splashy.
Pools. Get it!?

Disclaimer: I have a BFA in Art, so I'm convinced there's a far better algorithm
than the awful one I came up with. Pull request button is thataway.

```ruby
# Initialize with a desired final distribution.
buckets = Splashy::Buckets.new( :easy => 0.3, :hard => 0.7 )

# You can also specify a limit on elements in the final selection, no matter
# how many objects you collect.
buckets = Splashy::Buckets.new( {:easy => 0.3, :hard => 0.7}, 5 )

# Fill one-by-one:
buckets.add( :easy, obj1 )
buckets.add( :hard, obj2 )

# Fill using blocks:
i = 0
buckets.fill do |total_count|
  bucket = [:easy, :hard][total_count % 1]
  total_count < 100 ? [bucket, object] : nil
end
buckets.fill( :easy ) do |total_count|
  total_count < 105 ? object : nil
end

# Get a distribution of objects:
buckets = Splashy::Buckets.new( :a => 0.01, :b => 0.19, :c => 0.80 )
10.times { |i| buckets.add( :a, "1#{i}") }
2.times { |i| buckets.add( :b, "2#{i}") }
40.times { |i| buckets.add( :c, "3#{i}") }
buckets.select
# Returns:
#   {
#     :a => ["10"],
#     :b => ["20", "21"],
#     :c => ["30", "31", "32", "33", "34", "35", "36", "37"]
#   }
```

Changelog
=========

* *0.1.0* - Several bug fixes, add `#neediest_buckets` method to `Buckets` to
allow you to choose which buckets to add to first if an element can be put in
multiple buckets, final distributions can now have empty buckets if it means
we meet the wanted distribution better (i.e. a 99% to 1% wanted distribution 
with 5 and 1 elements, respectively, which will now select 4 and 0 elements if your wanted count is 4).
* *0.0.2* - Raise `ArgumentError` when trying to add to a bucket that doesn't 
exist, don't consider an empty bucket "satisfied".
* *0.0.1* - Initial release.

Contributing
============

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

Copyright
=========

Copyright (c) 2011 Tyson Tate. See LICENSE.txt for further details.
