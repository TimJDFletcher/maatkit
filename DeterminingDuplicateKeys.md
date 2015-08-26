# Introduction #

In response to [issue 9](https://code.google.com/p/maatkit/issues/detail?id=9) and [issue 269](https://code.google.com/p/maatkit/issues/detail?id=269), this page outlines the rules and procedures by which we determine that one key duplicates another. Determining duplicate keys is not a trivial task past identifying the simplest, most obvious cases. It is primarily all the subtleties needed to address issues of uniqueness which merit putting the rules in writing.

We begin with some terminology which, as far as I can see, is not standardized anywhere else. This is important because whether or not a key is a "dupe" (duplicate) can depend on some very fine details that need equally fine terminology.

Then, we will go case-by-case from simplest to most subtle and outline when and why one key dupes another.

# Terminology #

The following terms are somewhat my own creation; they may not be the best at this point, but their purpose is more clarification than technical acuity. These terms are not consistently used in the relevant modules (DuplicateKeyChecker.pm, TableParser.pm, etc.).

## Class ##

Key classes: primary, foreign, unique, ordinary

In developing a systematic approach to comparing sets of keys I found that it was helpful to classify the keys as either primary, foreign, unique or ordinary (ordinary can mean "not unique and not foreign"). The primary class only ever has one key, the PRIMARY KEY. The unique and ordinary classes have many keys. These classifications make comparison easier because, when a dupe is found, we prefer the key in one class and consider the key in the other class the duplicate. Which class is preferred and which is removable depends--we'll see this later.

For example, when comparing the primary class to any other class, since the PRIMARY KEY is never removed, the key in the other class is always the duplicate.

A class can be compared to itself. For example, ordinary keys are compared to one another. In such cases, the preferred key is the one with the most cover (cover is term defined later).

Foreign keys are a special class. They are generally not compared with the other classes.

## Structure ##

Key structures: btree, hash, spatial, fulltext

The structure of keys changes how we determine duplicates. Fulltext keys, for example, are order-independent (i.e., prefixes do not matter), but btree keys are not.

## Cover ##

Covers simple means how many columns a key covers. The key (a, b, c) covers three columns.

## Prefix ##

Prefix means the common left-most columns of two keys in order. Given keys (a, b) and (a, b, c), the first key is a prefix of the second. Being a prefix implies having less cover than the other key that it prefixes. (Neither key (a, b) nor (a, b) is a prefix; they are exact duplicates.)

The most basic type of duplicate key is a prefix in the same class. When comparing different key classes, the rules change.

One issue that we have not addressed yet is column prefixes, like a(23) for string columns.

## Unique Constraint ##

Unique constraint applies more to sets of columns than individual columns. In simple cases like UNIQUE KEY (a), it is clear that column a is constrained to uniqueness. However, in cases like UNIQUE KEY (a, b), it is the ordered _set_ a-b that constrained to uniqueness.

# Determining Duplicate Keys #

## Unconstrain Redundantly Unique Keys ##

The first step in determining duplicates is the nontrivial task of unconstraining redundantly unique keys. This means determining which unique keys do not need to be unique and can therefore be considered members of the ordinary key class. We must first make clear the distinction between constraining a column verses a set to uniqueness.

UNIQUE KEY (a) constrains the _column a_ to uniqueness. In no case can the column a have a duplicate value. (Yes, I'm stating the obvious.) (This may technically be a single element set, but I don't think this distinction is necessary.)

UNIQUE KEY (a, b) constrains the _ordered set a-b_ to uniqueness. In no case can the set a-b have a duplicate value (where "value" in this sense is an ordered 2-tuple). Since the set is ordered, the values (1, 2) and (2, 1) are not duplicates.

With those two distinctions, we define some formal premises that we use to determine whether or not a unique key can be unconstrained:

  1. If a key is PRIMARY or UNIQUE, then the key is unique
  1. If a unique key is defined which covers exactly one column, then the column is unique
  1. If a unique key is defined which covers at least two columns, then the columns are an explicitly unique set
  1. If an ordinary key is defined which covers at least two columns, then the columns are a non-unique set
  1. If there is at least one unique column or at least one explicitly unique set in a non-unique set, then the non-unique set is an implicitly unique set
  1. If there is at least one unique column in an explicitly unique set, then the explicitly unique set is redundantly constrained
  1. For all redundantly constrained explicitly unique sets, if the set is not the PRIMARY KEY, then the unique key which defines the set can be unconstrained

Premises 1-4 establish definitions for clarity. Premise 5 distinguishes sets which are unique because they're defined by a unique key from sets which are effectively or implicitly unique only because they include a unique column or unique set so that we do not remove such implicitly unique sets. Premise 6 defines the criteria for a key being considered redundantly unique. Premise 7 prevents us from removing the PRIMARY KEY.

Now let's consider some examples and for each we will apply the premises to conclude which unique keys can be unconstrained. In many cases, unconstrained unique keys will be prefixes and removed later when ordinary keys are compared to ordinary keys (see next section).

Example 1: Given the keys,

```
   PRIMARY KEY (a)
   UNIQUE KEY  (a, b)
   KEY         (a, b, c)
```

the UNIQUE KEY can be unconstrained. The PRIMARY KEY will constrain to uniqueness both column a and set a-b which is a subset of the implicitly unique set a-b-c defined by the ordinary key. As the UNIQUE KEY (a, b) is unconstrained to KEY (a, b), it also becomes a redundant key, as is becomes a prefix for the KEY (a, b, c).

Example 2: Given the keys,

```
   UNIQUE KEY (a)
   UNIQUE KEY (a, b)
   KEY        (a, b, c)
```

the second UNIQUE KEY can be unconstrained. The first UNIQUE KEY will constrain to uniqueness both column a and set a-b which is a subset of the implicitly unique set a-b-c defined by the ordinary key. As in Example 1, the UNIQUE KEY can be not only unconstrained, but removed.

Example 3: Given the keys,

```
   PRIMARY KEY (a, b)
   UNIQUE KEY  (a)
   KEY         (a, b, c)
```

no key can be unconstrained. The PRIMARY KEY is never removed, and the UNIQUE KEY is not a redundantly constrained explicitly unique set.

Example 4: Given the keys,

```
   UNIQUE KEY (a),
   UNIQUE KEY (a, b)
```

the second UNIQUE KEY can be unconstrained. The first UNIQUE KEY will constraint to uniqueness column a and any potential set which includes column a.

Example 5: Given the keys,

```
   PRIMARY KEY (a)
   UNIQUE KEY  (b)
   UNIQUE KEY  (c)
   UNIQUE KEY  (a, c)
   KEY         (a, b, c)
   KEY         (b, c)
```

the third UNIQUE KEY (a, c) can be unconstrained. The PRIMARY KEY and the first two UNIQUE KEYs will constrain to uniqueness columns a, b and c respectively.

## Remove Prefixes ##

Now that redundantly unique keys have been unconstrained, the second and final step in determining duplicates is finding and removing prefixes. This is done by comparing key classes in order of importance:

  1. primary
  1. foreign  (special case)
  1. unique
  1. ordinary

We do a top-down process of prefix elimination among the key classes. When comparing different classes, we keep keys in the higher class and remove them from the lower class. When doing an intra-class comparison (e.g., ordinarys to ordinarys), we keep the keys with the most cover and remove the prefixes.

The specific order of comparisons is:

  1. primary - unique
  1. primary - ordinary
  1. unique - ordinary
  1. ordinary - ordinary

The end result is that each class is left with only the minimum number of keys need to provide the same cover and access to all the columns previously indexed by the eliminated dupes.

There is one little but very important rule that affects the comparison of primary to unique keys:

  * A unique key cannot be removed if covers exactly one column (see premise 2 in the preceding section)

This rules prevents the loss of column uniqueness in cases like,

```
   PRIMARY KEY (a, b)
   UNIQUE KEY  (a)
```

because, without this rule, the unique key would be removed since it is a lower-class prefix of the primary key. This rule, however, does not prevent one of two exact duplicate unique keys which cover the same single column from being removed. In such cases, the first unique key encountered is kept and all other exact duplicate are unconstrained (i.e., moved to the ordinary key class where they will be removed as duplicates of one another).

### Systematic Approach for Removing Prefixes ###

The work to actually remove prefixes is done in DuplicateKeyFinder::remove\_prefix\_duplicates().  The following explains the internal mechanics of that subroutine.

We most often compare two different classes of keys (see the specific order of comparisons above), so we loop through two lists of keys: left keys and right keys.  In the first comparison, primary - unique, the primary key is the left key (a single element list) and the unique keys are the right keys.  Left keys are always either a higher class or the same class as right keys.  Therefore, **Left keys** are never removed, they are **Left alone**, whereas **Right keys** are **Removed** when a duplicate is found.

Left and right keys can be the same list.  This happens when we compare unique to unique and ordinary to ordinary keys.  In this case, it is still only right keys that are removed.  As right keys are removed the list of left keys becomes shorter but this does not create a problem for two reasons: one, any undefined left keys are skipped (these were right keys that were removed), and two, there is a `$right_offset` variable which keeps the loop for right keys always one key ahead of the the left keys loop so that we do not compare the same key to itself as both a left and right key.

Before any work is done, the keys are sorted either in ascending or descending order.  If the left and right keys are different lists, then they are sorted ascending; if they are the same list, then they are sorted descending.  We'll look at examples to see why this matters.

Suppose we are given the following keys:
```
   LEFT       RIGHT
   =======    =======
   a          a
   a, b       a, b, c
   a, b, c
```
As you can see, they're different lists and so we've sorted them ascending.  Now we loop through each left key and compare it to all right keys.  This is always the loop order: left key, compare to all right keys, next left key, etc.  The comparison is a line like:
```
   if ( substr($left_key, 0, $right_key_length) eq substr($right_key, 0, $right_key_len) ) {
      # Right key is left prefix duplicate of left key; remove right key
   }
```
Notice that we always use the right key's length, even for the left key.  The first comparison in the keys above, `a` to `a`, is obviously an exact duplicate so the substrings will be equal and the right key will be removed.  The second comparison will be between left key `a` and right key `a, b, c`.  So the comparison will look like:
```
   if ( "a" eq "a, b, c" ) {
```
Perl substr() ignores lengths which exceed the real length of the string, so the left key remains just `a`, not `a` plus padding to make it as long as the right key.  Then, of course, that comparison fails and we get the next left key and continue.

Here's a list of all the comparisons and their results:
```
   COMPARISON            RESULT
   ==========            =============================
   a eq a                Remove right a
   a eq a, b, c          Prefix but cannot remove a
   a, b eq a, b, c       Prefix but cannot remove a, b
   a, b, c eq a, b, c    Remove right a, b, c
```

To demonstrates why we use the right key's length even for the left key, suppose that we compare left key `a, b, c` to right key `a, b`.  The right key is shorter so, using its shorter length for left key, the comparison is effectively `a, b eq a, b` which is true so the right key is correctly removed.  But if we use left key's real length then the comparison `a, b, c eq a, b` would not be true even though `a, b` is a left prefix of `a, b, c` and it can be removed (since it's a right key).

Now let's compare a list of keys to itself. We'll sort them **incorrectly** at first to illustrate why the sort order matters.
```
   LEFT       RIGHT
   =======    =======
   a          a
   a, b       a, b
```
Left keys and right keys are the same list (reference to the same array), and they are sorted ascending which is incorrect.  Only one comparisons results: `a eq a, b` which is a prefix but `a` cannot be removed (it's the left key).  Since left and right keys are the same list and right key must be kept one ahead of left key so we don't compare a key to itself, no more comparisons are possible.  If we tried to use left key `a, b` then right key would have to be one past this but there is no such element (remember, they're the same array).  We could code exceptions to handle this case, but that would be less clean and simple than correctly reverse sorting the keys.

When the same list of keys are sorted **correctly**, which is descending, we get:
```
   LEFT       RIGHT
   =======    =======
   a, b       a, b
   a          a
```
Then the only one comparison is `a, b eq a` which is a prefix and `a` can be removed since it's the right key.  So instead of an awkward exception like "if the lists are the same and we're on the last left key then ignore the right key offset and loop the right key list from the top", we simply reverse sort the lists if they're the same and then the same code that works for two-list scenarios auto-magically works for same-lists scenarios.

# Outstanding Issues (TODO) #

These are issues that have yet to be fully addressed:

  * Foreign keys
  * Prefixes for string columns
  * Might the nullability of a column be a consideration?
  * Is unique (a, b) a dupe of unique (b, a)? Constraint-wise yes, but execution plan-wise no.