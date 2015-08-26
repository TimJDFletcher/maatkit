# Synopsis #

EventAggregator takes hashrefs and aggregates them as you specify. It basically does a GROUP BY. If you say to group by z and calculate aggregate statistics for a, b, c then it manufactures functions to record various kinds of stats for the a per z, b per z, and c per z in incoming hashrefs.

Usually you'll use it a little less abstractly: you'll say the incoming hashrefs are parsed query events from the MySQL slow query log, and you want it to calculate stats for Query\_time, Rows\_read etc aggregated by query fingerprint.  It automatically determines whether a specified property is a string, number or Yes/No value and aggregates them appropriately.

# Buckets #

To calculate statistical metrics for an attribute, all values for that attribute need to be saved. Instead of saving all the actual values in a potentially huge array, we count the occurrences of small ranges of values. These small ranges are "buckets".

Buckets are really just elements in an array. Since each bucket covers a range of values, we can use a limited number of buckets to count the occurrences of a much larger number of actual values because a lot of values will be roughly the same and therefore will fall into a common bucket.

We lose some precision in our calculations by using buckets, but the trade-off is that we save memory and improve speed. The degree of precision loss is determined by the size of the buckets that we choose. Sizes refers to the ranges of values that a bucket covers. A big bucket will cover a lot of values and be imprecise; a little bucket will cover only a few values and be more precise.

Precision is also affected by the number of buckets that we choose. Since statistical metrics are usually done on values ranging from 0.000001 to very large integers, we use 1,000 buckets to cover all these potential values. (0 values are covered, too.) With 1,000 buckets, each bucket can be pretty small and, altogether, still cover all potential values. The fewer buckets we use, the larger each bucket has to be to cover all potential values.

As long as our bucket sizes are not too big, 1,000 buckets is more than sufficient, so we fix that number to make things simpler. Then the question becomes: what sizes are the buckets and, more importantly, how do we determine these sizes?

Determining bucket sizes is a challenge because, with 1,000 buckets, we cannot do this efficiently if we do it manually. The solution is to use log functions with smaller bases than 10 (standard log) or _e_ (natural log).

Since log functions are not intuitively used for making buckets, we'll take a close look at how this works. This examination will also serve as our proof because I cannot intuitively prove to myself that 0.000076886 is the first value of bucket 89 when using base1.05, but I can prove it mathematically.

## Simple Example and Fundamental Concepts ##

As a first example, let's see how log10 can be used to determine into which bucket a value falls and the range of values that each bucket covers. Plugging our values for x into log10 we get:

| val (x) | log10(val) | bucket (y) |
|:--------|:-----------|:-----------|
| 1       | 0          | 0          |
| 5       | 0.69897    | 0          |
| 9       | 0.95424    | 0          |
| 9.999   | 0.99996    | 0          |
| 10      | 1          | 1          |
| 15      | 1.1761     | 1          |
| 99      | 1.9956     | 1          |
| 100     | 2          | 2          |

The bucket for each val is determined by taking the whole integer val of log10(val) (Perl's [int()](http://perldoc.perl.org/functions/int.html)). The table shows that values `[1, 10)` (review [interval notation](http://en.wikipedia.org/wiki/Interval_notation) if that looks bizarre to you) fall into bucket 0. Likewise, values `[10, 100)` fall into bucket 1, values `[100, 1000)` (not shown) fall into bucket 2, etc. Is this magick? No, just algebra.

Notice that the beginning value for each bucket is a power of 10 (the log base a) and then recall the relation between logarithm and exponential:

> y = log<sub>a</sub>x `<=>` x = a<sup>y</sup>

or, using our own terms:

> bucket = log<sub>a</sub>val `<=>` val = a<sup>bucket</sup>

With that relation, you can approach the problem from the other direction by asking, "What is the minimum (first) value `x` given bucket `y` and base `a`?" Since you know `a` and `y`, `x` is a trivial calculation. And just to test it, if we use anything less than 1 for bucket, value will be less than `10` for example:

> `10`<sup>0.999999</sup> = 9.999976

So, in other words, the first value of a bucket is equal to base (`a`) to the power of the bucket. We'll see later, however, that there's more to this when we use a more complex example.

Knowing how to calculate the first value of a bucket allows us to determine the range of values covered by the bucket. The range of a bucket is:

> `[x = a`<sup>y</sup>`, x = a`<sup>y+1</sup>`)`

That says that a bucket covers all values from its first value up to but not including the first value of the next bucket.

Finally, we can now also see the positive correlation between our chose base `a` and bucket size: the bigger the base, the larger the difference between the first values of adjacent buckets and thus the bigger the buckets. For example:

| base `a` | bucket 0 | bucket 1 | bucket size |
|:---------|:---------|:---------|:------------|
| 10       | 1        | 10       | 10          |
| 5        | 1        | 5        | 5           |
| 1.5      | 1        | 1.5      | 1.5         |

Again, there's more to this when we use a more complex example.

In summary, the fundamental concepts are:

  * The bucket into which a value falls is a function of log<sub>a</sub>x, where x = value
  * The first value of a bucket equals a<sup>bucket</sup>
  * The range of a bucket is `[x = a`<sup>y</sup>`, x = a`<sup>y+1</sup>`)`
  * Bucket size is positively correlated to the size of `a`

## Complex Example ##

Base 10 creates buckets that are too big, too imprecise. EventAggregator uses log base 1.05. Also, unlike the simple example, we need to handle all values from -infinity to infinity, even though in an ideal world we should only get values `[0, 0.000001)U[0.000001, infinity)`. Then, we need to handle zero values specially because the domain of log functions is `(0, infinity)`, and we also need to handle values < 0.000001 specially because they will yield negative buckets after we offset our base. So, there's a lot more to explain here.

Before we being, we'll need the base change forumla because Perl [log()](http://perldoc.perl.org/functions/log.html) is natural log, not log10 and because we will be using a base less than 10 or _e_:

> log<sub>a</sub>x = log<sub>b</sub>x / log<sub>b</sub>a

For brevity, I won't repeat this formula, I will just use "base1.05".

Since buckets are array elements and array elements are indexed starting with zero, the first thing we need to do is offset log1.05 so that the minimum value in our domain (0.000001) equals the first (minimum) value of bucket 0. If we don't do this, problems arise because log of any base is negative in the interval (0, 1), and no one wants to hassle with negative buckets.

Solving this problem is simple: the absolute value of log1.05(0.000001) is our "BASE\_OFFSET," a constant defined at the beginning of EventAggregator.pm. If you look at the code, you'll notice that we subtract this value from 1; the relevant lines of code are currently:

```
   use constant BUCK_SIZE    => 1.05;
   use constant BASE_LOG     => log(BUCK_SIZE);
   use constant BASE_OFFSET  => abs(1 - log(0.000001) / BASE_LOG); # 284.1617969
```

This leads us to the second problem: handling zero values. Zero is not in the domain of log, but we have to handle zero values because they occur in the real world. We solve this problem by shifting all the buckets in the array up by one, leaving bucket 0 (array index 0) for zero values. (Actually, it's for zero values and all values < 0.000001.) Thus, BASE\_OFFSET is increased by one to accomplish this one-up shift of buckets.

BASE\_OFFSET is added to the result of log1.05(x) for any value x. Let's look at some examples to see this in action:

| val (x) | log1.05(val) | + BASE\_OFFSET = bucket |
|:--------|:-------------|:------------------------|
| 0       | not defined  | 0                       |
| 0.000001 | -283.1617969 | 1                       |
| 0.1     | -47.1936328  | 236                     |
| 1       | 0            | 284                     |
| 100     | 94.3872656   | 378                     |

Notice how 1, which used to be bucket 0, is now bucket 284, the same integer value as BASE\_OFFSET.

Now that we can calculate the bucket for any value including zero, we need to calculate the first (minimum) value of any bucket taking into account the one-up shift of buckets (so bucket 1 is really bucket 0, etc.) From the simple example, we know this equals a<sup>base</sup> but if you try it, you'll see it doesn't work because, for example, 1.05<sup>0</sup> equals 1 but we know from the table above that the first value in bucket 1 should be 0.000001. This is because val = a<sup>bucket</sup> (x = a<sup>y</sup>) actually gives us the factor by which the minimum value in our domain is increased at a given bucket (`y`). Therefore, in this example, we have to multiply the result of a<sup>bucket</sup> by 0.000001, which gives us correct bucket starting values. Then using the same principle in the simple example to find a bucket's range, we get the following buckets for log1.05 (taking into account special bucket 0 and the one-up shift):

| bucket | range |
|:-------|:------|
| 0      | `(-infinity, 0.000001)` |
| 1      | `[0.000001000, 0.000001050)` |
| 2      | `[0.000001050, 0.000001103)` |
| 3      | `[0.000001103, 0.000001158)` |
| etc.   | etc.  |