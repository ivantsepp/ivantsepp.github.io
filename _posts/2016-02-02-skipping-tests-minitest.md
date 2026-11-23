---
layout: post
title: "Skipping tests in Minitest"
date: 2016-02-02
description: "There are many ways to skip tests in Minitest but be careful of the default way"
categories: ruby minitest testing
other_blog: Paperless Post
comments: true
---

*This post was originally published on the [Paperless Post engineering blog](https://web.archive.org/web/20190113200950/https://www.paperlesspost.com/blog/teams/skipping-tests-minitest/) (via the Wayback Machine).*

We’ve all been there: Maybe you have a flaky test that you don’t have the time to fix right now, or you want to start writing tests for some future work that you aren’t ready to implement yet. At Paperless Post, sometimes we want to skip flaky acceptance tests until someone has a chance to look at them. This keeps our builds green and maintains confidence in our tests. I did a [code search on Github](https://github.com/search?o=desc&q=skip+minitest+extension%3Arb+path%3Atest+size%3A%3E5000+fork%3Afalse&ref=searchresults&s=indexed&type=Code&utf8=%E2%9C%93) and found we’re not the only ones doing this. All of this goes to show that there are a variety of valid cases for skipping tests. However, the current implementation of skipping tests can be costly.

Skipping tests in Minitest is simple; use the `skip`  method to signal to Minitest that the test method should be skipped when running a test suite. Here’s an example:

```ruby
require "minitest/autorun"

class MyTest < Minitest::Test

  def test_one
    skip "Dependency has changed and this test needs to be fixed"
    # ...
  end
end
```

Let’s take a quick look at how `skip`  is implemented by diving into Minitest source code. First, let’s look at the method definition of skip.

```ruby
##
# Skips the current run. If run in verbose-mode, the skipped run
# gets listed at the end of the run but doesn't cause a failure
# exit code.

def skip msg = nil, bt = caller
  msg ||= "Skipped, no message given"
  @skip = true
  raise Minitest::Skip, msg, bt
end
```

This is the implementation of `skip` and all it does is raise a `Minitest::Skip` exception. `Minitest::Skip` inherits from `Minitest::Assertion` which inherits from `Exception`. Minitest captures abnormal behavior such as failing assertions and unexpected errors from your test code, and uses exceptions to communicate to the test runner. When Minitest runs the test, it catches the exception and uses the exception to determine the state of the test. Below is a snippet of the relevant code that handles the exception:

```ruby
def capture_exceptions # :nodoc:
  yield
rescue *PASSTHROUGH_EXCEPTIONS
  raise
rescue Assertion => e
  self.failures << e
rescue Exception => e
  self.failures << UnexpectedError.new(e)
end

##
# Was this run skipped?

def skipped?
  self.failure and Skip === self.failure
end
```

Minitest catches the exception and adds it to a list of failures, but then it has to distinguish between an actual failure or a skip. It does this by using [`Module#===`](http://ruby-doc.org/core-2.2.0/Module.html#method-i-3D-3D-3D).

The takeaway from reading the source code is that Minitest raises exceptions to communicate skips, which means that a test is not skipped until `skip` is called. `skip` halts execution at the current line and only then is the test is marked as skipped. The implication of this is that any code executed before `skip`, such as setup methods, is essentially wasted time.

Here’s a more concrete example of this:

```ruby
require "minitest/autorun"
class MyTest < Minitest::Test

  def setup
    sleep 2
  end

  def test_one
    skip "This is run and executes the setup block. This test takes 2 seconds to run"
  end
end
```

This can be especially costly if you use skip in an acceptance test, which might have a long and complicated setup. This is something we’ve run into at Paperless Post, since our acceptance tests set up by opening a browser and navigating to the homepage.

So what can we do to improve this? A straightforward answer would be to delete the test or to comment it out. We could even create GitHub issues if we were concerned that no one would come back to the test and fix it. Even so, this is not an ideal solution since we do not get the Minitest output that shows the number of skipped tests in need of attention.

Deleting or commenting out a test also doesn’t work for cases where `skip` is used conditionally depending on some runtime state.

For example:

```ruby
def test_something
  skip "message" if RUBY_ENGINE == 'rbx'
  # ...
end
```

One solution would be to conditionally define the method.

```ruby
if RUBY_ENGINE == 'rbx'
  def test_something
    # ...
  end
end
```

A more elegant way of doing the above is ([credit goes to Ryan Davis](https://twitter.com/the_zenspider/status/694993398046916608))

```ruby
def test_something
  # ...
end unless rubinius?
```

Still, there are other cases where you can’t avoid using `skip`. Here’s an example from [active_shipping](https://github.com/Shopify/active_shipping/blob/37b8f4a64364ebc0eaeacc386a8c36ce6bee0638/test/remote/ups_test.rb):

```ruby
def test_obtain_shipping_label_with_bill_third_party
  begin
    bill_third_party_credentials = credentials(:ups_third_party_billing)
  rescue NoCredentialsFound => e
    skip(e.message)
  end
end
```

Although there are alternatives to using the costly skip – including deleting, commenting out, or renaming the test – these are all still not ideal because they cannot use Minitest reporting facilities to tell us which tests have been skipped.

I’ve created a plugin to help solve that, which allows you to skip methods by renaming them to begin with `skip_`. This plugin patches Minitest so that it can find methods that begin with `skip_` and records them as skipped tests without running any setup code. [Check out the code here!](https://github.com/ivantsepp/minitest-skip) Here’s how it would look on a previous example:

```ruby
require "minitest/autorun"
class MyTest < Minitest::Test

  def setup
    sleep 2
  end

  def skip_test_one
    # the setup block is not executed
  end
end

# Output correctly shows that this test was skipped

# Run options: --seed 14032
#
# # Running:
#
# S
#
# Finished in 0.001937s, 516.2940 runs/s, 0.0000 assertions/s.
#
# 1 runs, 0 assertions, 0 failures, 0 errors, 1 skips
#
# You have skipped tests. Run with --verbose for details.
```

In conclusion, we’ve seen that skip is necessary and useful in some cases but the way that it is currently implemented can be costly, particularly if there’s expensive setup logic. One solution is to remove skipped tests or conditionally define them, but then you lose helpful Minitest output. An even better solution is to use [this plugin](https://github.com/ivantsepp/minitest-skip) that avoids costly setup but still provides helpful test output. Also, if you have time, try reading Minitest’s source code. It’s very readable and well written!

Thanks to [Becca Liss](https://twitter.com/becdot) and [Yanik Jayaram](https://github.com/modernlegend) for helping me out on this post.
