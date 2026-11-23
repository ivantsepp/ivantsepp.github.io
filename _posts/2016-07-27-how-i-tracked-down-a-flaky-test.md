---
layout: post
title: "How I Tracked Down a Flaky Test"
date: 2016-07-27
description: 'My journey of fixing a flaky test, this was featured in a <a href="http://rubyweekly.com/issues/308">Ruby Weekly Issue</a>!'
categories: ruby testing
other_blog: Paperless Post
comments: true
---

*This post was originally published on the [Paperless Post engineering blog](https://web.archive.org/web/20190113173735/https://www.paperlesspost.com/blog/teams/how-i-tracked-down-a-flaky-test/) (via the Wayback Machine).*

TLDR: I had trouble figuring out the root cause of a flaky test. I made several theories and used lots of logging to debug the issue. It turns out that this flake only occurs when 4 test files run in a specific order. The issue was that global state was leaking through each test run from improper use of Timecop.

## What Is A Flaky Test And Why Do We Care?

Testing is an important aspect of software development. Tests are used to prevent regressions and allow developers to refactor code with confidence. It’s particularly helpful to run these tests continuously, especially if the tests take more than a couple of minutes to run. At Paperless Post, our unit test suite takes about 5 minutes to complete so we run them on our continuous integration server: Jenkins, which runs these builds on every commit that gets pushed.

We noticed that some builds initially fail, but pass when they are rebuilt. And when we run the exact same test locally, it always passes. This is not a good sign; these are the symptoms of flaky tests. Unlike many bugs, flaky tests are really hard to fix because they’re so hard to reproduce.

One option to address this is to simply ignore these failures, but this is not a good practice. Developers will start lose trust in the tests and will begin to ignore failed builds without looking at the specific failures. Even if all the developers are disciplined enough to look at each failed build, they have to look at the build report to determine whether or not the build failed as a result of a real bug or a flake. This behavior is described in the [broken windows theory](https://en.wikipedia.org/wiki/Broken_windows_theory). Sooner or later, our test suite will accumulate more and more flakes to a point where the tests are not useful or beneficial anymore. So, I decided to jump in and try to determine the root cause of this issue. The following is a recount of my journey.

## Reconnaissance

First, let’s take a look at the test failure. In this test, we are trying to render a view by doing a GET request. More specifically, we are rendering the cart modal. This is the failure:

```text
1) Error:
CartsControllerTest#renders_cart_modal
ActionView::TemplateError: Called id for nil, which would mistakenly be 4 -- if you really wanted the id of nil, use object_id
   On line #50 of app/views/carts/_cart_modal.html.haml

   48:           - if current_cart.has_print_orders?
   49:             - current_cart.print_orders.each do |print_order|
   50:               = print_order.related_event.id.to_param
```

The exception is coming from the fact that `print_order.related_event` is returning `nil`. We want to understand why it’s returning a `nil` value but we don’t have the luxury of inspecting the failed test run interactively. Instead, we have to do detective work. We have to gather some clues about the state of the process at the time of the failure. Let’s start by stating the facts. What can we say is true about the system? In the snippet, `current_cart.has_print_orders?` has to return `true` in order for the test to enter that conditional. So I took a look at the method:

```ruby
class Cart < ActiveRecord::Base

  has_many :orders, proc { where(:removed => false) }

  def print_orders
    @print_orders ||= orders.where(print: true).order('orders.created_at DESC').to_a
  end
end
```

In that method, I learned that carts have an association of `has_many :orders`, and this method was scoping those orders to print orders as opposed to non-print orders. We also know that with a print order, we can find its related event. In addition to learning about the code, you can also inspect the environment in a successful test run to see what *should* be happening. I put a `binding.pry` statement in that test and saw that the `current_cart` has several `print_orders`, each with a `related_event`.

## Making An Hypothesis: Indeterministic Ordering

After gathering some clues, you can make some hypotheses. Did the `related_event` get deleted in another test? No, that shouldn’t be possible because we are using transactional fixtures. This means that each test is wrapped in a transaction so that any changes performed in a test are rolled back. In the test we’re looking at, there aren’t any `destroy` calls. So even if another test deleted that event, it should be rolled back by the time this test started. Did an invalid print order get created and associated with the cart? Again, it shouldn’t be possible for our test because of transactions. Is `current_cart` returning the right cart? Hm, that is an interesting idea. Let’s take a closer look at the `current_cart` helper method.

```ruby
def current_cart
  @current_cart ||= current_account.current_cart
end
```

It looks like it’s grabbing the logged-in account and calling `#current_cart` on that account.

```ruby
def current_cart
  carts.where(:complete => false).order("updated_at DESC").first
end
```

Aha! What if the `current_account` has multiple carts? The query that’s generated above is `SELECT * FROM "carts" WHERE ("carts".account_id = <id>) AND ("carts"."complete" = 'f') ORDER BY updated_at DESC LIMIT 1`. Could it be returning the wrong cart? This reminded me of a recent issue that one of our engineers, Becca, observed. She saw that some records were missing and others were duplicated in a paginated API json response. Both these issues are similar and sounds like it could be an indeterministic ordering issue. But what is indeterministic ordering?

The fundamental reason for indeterministic ordering is because of how relational databases are implemented and how the SQL language is specified. The [Postgres documentation](https://www.postgresql.org/docs/8.3/static/queries-order.html) says:

> After a query has produced an output table (after the select list has been processed) it can optionally be sorted. If sorting is not chosen, the rows will be returned in an unspecified order. The actual order in that case will depend on the scan and join plan types and the order on disk, but it must not be relied on. A particular output ordering can only be guaranteed if the sort step is explicitly chosen.

Without an `ORDER BY` clause, the records can be returned in any way that’s convenient to the database. In addition, if you specify a column for `ORDER BY` where several records have the same value, those records can be returned in any fashion.

This is a common issue and is an easy trap to fall into. Rails even changed their first and last [ActiveRecord implementations](https://github.com/rails/rails/pull/5153) in Rails 4 to address this behavior. One solution is to use a unique column to order by. This [article](https://thomascannon.me/posts/pagination-perils) goes into more detail about this issue and how to fix it.

Let’s take a look at the carts in our test environment. Lo and behold, the fixtures file:

```yaml
cart_1:
  account: account_1

invalid_cart:
  account: account_1
```

`account_1` is the logged in user for our test and it has several carts. Since we didn’t specify any timestamps for `created_at` or `updated_at`, they all have the same `created_at` and `updated_at` timestamps.

So, our theory is that the query in `Account#current_cart` is indeterministic and that any of these carts could be returned. We believe that `carts(:invalid_cart)` is being returned in some cases and it has a print order that does not have a related event. This explains the error and the stacktrace we were seeing. To fix this, we could update our query by adding an “order by” with a more specific clause such as `order("updated_at DESC, id DESC")`. Or we could update the fixture file so that the carts have different timestamps.

So I decided to fix it with the latter approach.

```yaml
cart_1:
  account: account_1
  updated_at: <%= 5.minutes.from_now %>
```

`cart_1` should be selected from now on since it should have the a later `updated_at` timestamp. An interesting takeaway from this discovery is that we might have other queries with indeterministic ordering. To identify those queries, we could patch ActiveRecord such that it appended a `ORDER BY random()` to every query and then seeing if other tests fail. I did just that and the results were interesting, but I’ll save that for another post.

I merged my changes believing that I have fixed the flake. But surprisingly, the flake is still happening! The same test and the same stacktrace were showing up in failed builds. Seems like my fix didn’t address the issue so it’s back to the drawing board.

## Put Logging Statements Everywhere

This time, I wanted to learn more about the environment of the failing test. I used `puts` debugging to print out all possible state such as local variables and their associations if they were ActiveRecord models.

Is `current_account` returning the right account? Yes. Is `current_cart` returning the correct cart? No. Let’s print out the account’s carts at the beginning of the failing test and right before the exception.

```text
# At the start of the failing test
[
 #<Cart id: 1, created_at: "2016-06-15 03:44:39", updated_at: "2016-06-15 03:49:38" .... >,
 #<Cart id: 2, created_at: "2016-06-15 03:44:39", updated_at: "2016-06-15 03:44:39" .... >
]

# Right before the exception
[
 #<Cart id: 2, created_at: "2016-06-15 03:44:39", updated_at: "2016-06-15 03:44:39" .... >,
 #<Cart id: 1, created_at: "2016-06-15 03:44:39", updated_at: "2016-06-15 03:40:23" .... >
]
```

At the start of the failing test, we can see the target cart (with id 1) and that it correctly contains an `updated_at` timestamp that is 5 minutes after the `created_at` timestamp. However, it looks like the `updated_at` timestamp of that cart changed somewhere in the failing test.

## Further Investigation (Spoiler Alert: Timecop)

## Jenkins/Host Problems

After I took a quick look at the controller code, I realized that we have some logic to set the default shipping option of an order if it doesn’t already exist:

```ruby
class CartsController < ApplicationController
  def cart_modal
    ...
    current_cart.shippable_orders
      .select { |o| !o.valid_shipping_option? }
      .each(&:set_default_shipping_option)
    ...
  end
end
```

This in turn touched the cart’s timestamp because of the association:

```ruby
class Order < ActiveRecord::Base
  belongs_to :cart, touch: true
end
```

So that explains why the `updated_at` timestamp changed. But what’s **really interesting** is that the timestamp used for `updated_at` is before the `created_at` timestamp. How did `Time.now` somehow end up going back in time?

I was extremely baffled from this behavior. My next hypothesis was that there is some weird time calculation going on in that Jenkins node. We run our tests on a single server so perhaps this is an OS level issue. I spun up a different Jenkins node to build our tests to see if flakes were only happening on that server.

## Timecop

Nope. The flakes still showed up. Our staff operations engineer, Dan Diego, had an interesting insight and suggested that perhaps this flake is related to [Timecop](https://github.com/travisjeffery/timecop). Timecop is a library that allows you to travel in time by essentially mocking what `Time.now` would return. I added more debugging statements to see if Timecop was in play. Timecop mocks the `Time.now` method by aliasing the original `Time.now` to `Time.now_without_mock_time` and overriding `Time.now` with `Time.now_with_mock_time`. Here’s the [implementation](https://github.com/travisjeffery/timecop/blob/314882f24065190c446d8d1eb368f6985885dd28/lib/timecop/time_extensions.rb#L6-L17). With that in mind, I wanted to see if time was mocked:

```ruby
puts Time.now_without_mock_time.inspect
```

Hm, nothing interesting came out of that `puts` statement. `Time` wasn’t being mocked when the flaky test is running. I then decided to record the time at the start of the test build in addition to the time when the flaky test is executed. Aha! The timestamps matched the weird `updated_at` timestamp. So actually, `Time.now` didn’t end up going back in time. Instead, the `created_at` timestamps for the carts are in the future! Somehow, those fixtures were created with a future `Time.now` instance.

I again was baffled from this finding. Fixtures are created at the start of the test build (the [entire fixtures implementation](https://github.com/rails/rails/blob/d0a5f878d32a4b95f5e866d3b5612acd4b7d16c7/activerecord/lib/active_record/fixtures.rb) is actually pretty succinct and readable). And the time at the beginning of the test suite is correct. I couldn’t think of a reason for why fixtures would be created with an incorrect timestamp.

## Transactional fixtures

After mulling this over for a while, I had another insight. We have some tests that turn off the transactional behavior of tests. This is because we needed to test functionality in `after_commit` callbacks. (This is [fixed](https://github.com/rails/rails/pull/18458) in Rails 5, you can test those callbacks while still having the transactional fixture behavior). Would setting `self.use_transactional_fixtures = false` be forcing fixtures to be reloaded? Yes, in fact that’s true! In the [implementation](https://github.com/rails/rails/blob/d0a5f878d32a4b95f5e866d3b5612acd4b7d16c7/activerecord/lib/active_record/fixtures.rb#L984-L989), Rails will remove existing records and re-insert them for each test case that have transactional fixtures off.

This is exciting because now we can explain why the cart would have a `created_at` timestamp in the future. `Time.now` must’ve been mocked when those tests are running. Looking at the implementation of Timecop, if we traveled in time, `Time.now` will stay mocked until we execute `Timecop.return` to unmock `Time.now`. In our codebase, for the most part we were following best practice by calling `Timecop.return` whenever we traveled in time. But there were cases where we didn’t do that.

So if a test traveled in time via `Timecop.travel(5.minutes.from_now)` and didn’t call `Timecop.return`, then our test runner would have its time mocked and it would be in the “future”. Afterwards, if the test runner executes a test that calls `Timecop.return`, then time would be restored to the real time.

Wow. So our hypothesis is that first we need to run the test that puts the test runner in the future, then run a test that resets fixtures, then run a test that returns the runner to the correct time, and then finally, run the flaky cart test. I ran these exact tests locally and once they ran in the order I described above, I finally was able to reproduce the error. This validates our hypothesis!

## Conclusion And The Fix

In the end, this flaky test issue boils down to misusing Timecop. We had a few lingering Timecop uses where we didn’t unmock time at the end of the test. The fix was simple enough: make sure we return to the correct time at the end of each test. As an interesting side note, ironically, I was the developer who wrote those tests that traveled in time. I guess that’s karma since I ended up spending time debugging and fixing these flakes.

The takeaway from this journey is to make sure you return time to its original time at the end of each test. In fact, I would recommend using `Timecop.return` as a global teardown block. Let’s take a quick look at its implementation:

```ruby
# Reverts back to system's Time.now, Date.today and DateTime.now (if it exists) permamently when
# no block argument is given, or temporarily reverts back to the system's time temporarily for
# the given block.
def return(&block)
  if block_given?
    instance.send(:return, &block)
  else
    instance.send(:unmock!)
    nil
  end
end

...

def unmock!
  @baseline = nil
  @_stack = []
end
```

It looks like Timecop resets some internal values to make sure that time is no longer mocked. The implementation doesn’t seem too costly with regards to performance and it seems that by doing it globally it would prevent future developers from making the same mistake that I did. And it makes sense too: after every test, you don’t want time to be mocked so we can go ahead and unmock time.

In conclusion, tests are an important aspect of software development and we as developers should make sure the tests are not flaky. And if we see flaky tests, we should spend the appropriate time debugging and fixing the issue. In our case, we saw that Timecop was acting like a global state that’s shared across tests. We misused Timecop and its state leaked into other tests causing unexpected behavior. Make sure to reset global states between tests to avoid flaky tests.

*Thanks to Brittany Wald, Jacy Clare, Mavreen Smiel, and David Cosgrove for reading and providing feedback to this blog post.*
