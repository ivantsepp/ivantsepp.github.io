---
layout: post
title: "The Rails View book notes"
date: 2014-11-13
description: "Interesting content that I've learned from reading this book"
categories: books notes
comments: true
---

[![The Rails View book cover](http://ecx.images-amazon.com/images/I/41kBEVA%2B7pL.jpg)](http://www.amazon.com/The-Rails-View-Maintainable-Experience/dp/1934356875)

# Overall Review

I actually learned a few new tips and tricks from this book. It was nice to read a book that's mainly focused on the view end of Rails. And I was surprised by the amount of things I learned since I didn't really know there was that much to talk about for views. However, the book did go in a bit of a tangent regarding Sass (I am biased though since I already knew the syntax before reading this book). Overall I would definitely recommend this book! Go check out their [website](http://www.therailsview.com/) and the [rules](http://www.therailsview.com/rules.pdf) they have on Rails view layer.

# Chapter 1
- If you don't specify the folder in the partial file name, Rails will look for the file in the current controller’s view directory
- Use `yield :sidebar`, `content_for :sidebar do`, and `content_for?(:sidebar)` to allow content in the view to hook into the layout.
- There is a nifty solution for how to handle navigation in Rails. Put nav in a partial that uses `content_for`. Then, use a helper method to render this partial with a local variable dictating what the current page is:
{% highlight ruby %}
def currently_at(tab)
  render partial: 'layouts/main_nav', locals: {current_tab: tab}
end
{% endhighlight %}

- `flash[:notice]`, `flash[:alert]` and the corresponding `alert`, and `notice` helper methods.
- [ie_conditional_tag gem](https://github.com/bruce/ie_conditional_tag)

# Chapter 2
- `raw` method (similar to `html_safe`), `link_to`, `image_tag`, `number_to_currency`, `number_to_human_size`
- Use this to avoid putting law of demeter solution in model and avoid being tied to having @creation present (it's a default parameter):
{% highlight ruby %}
def creation_client_name(creation = @creation)
  creation.project.client.name
end
{% endhighlight %}

- Use this to render collections so that the html for an item is abstracted away as well as the iteration (which should be Rails responsibility):
{% highlight ruby %}
<%= render @creations %>
{% endhighlight %}

- Move if/elsif/else clause into separate partials and a helper that renders the correct partial:
{% highlight ruby %}
<%= controls_for_creation(creation) %>
{% endhighlight %}

- extract long conditions to method_name? helpers. You can even `yield` in that method so that it can take a block of html
- Use content_tag_for when attributes become complex (use `dom_id`)

# Chapter 3
- sprockets looks in these folders: `app/assets` for application code, `lib/assets` for code used in several projects, `vendor/assets` for 3rd party code
- directives: `require_tree` to require a directory recursively and alphabetically, `require_self` for the file itself
- `rails runner "y Rails.configuration.assets.paths"` to see where sprocket finds the files
- Use require when you just want to shove content together and @import when you want to use the definitions present in the dependency in the current file
- `asset-path` and `image-path` Sass functions
- sprites (use compass)
- `@font-face` css declaration
- `stylesheet_link_tag`

# Chapter 4

- `javascript_include_tag` (`include_js`)
- jquery_ujs
  - `confirm` parameter to `link_to`
  - `remote` parameter to a form (render a js partial)
- `j`/`escape_javascript` method

# Chapter 5
- `form_for` (`multipart` option), `text_field`, `label`, `file_field`, `submit`, `form_tag`
- html fieldsets
- tabindex for tabbing order
- optgroup for grouping options. Pass an array of arrays to `select_tag`
- autofocus (html5)
- Rails automatically wraps div with field_with_errors
- form builder `error_messages` method (https://github.com/joelmoss/dynamic_form)
- `fields_for`
- `ActionView::Helpers::FormBuilder` You can subclass this to add methods to the form builder object. Ex:

{% highlight ruby %}
def field_item(attribute, text = nil, &block)
  @template.content_tag :li do
    @template.concat @template.label(attribute, text)
    yield
  end
end
{% endhighlight %}
pass `builder` paramter to `form_for`

- input tag has new type options from html5

# Chapter 6
- Make a presenter object and an associating helper method. Use a block so that the presenter object is yielded instead of assigning a variable for the presenter.
- We pass along the presenter instance using the `:object` option, which will make sure it's assigned to a variable with the same name as the partial (in this case, status). This allows the partial to call methods on this object directly
- We can make presenters render itself. Pass `self` to the presenter (self is the template object). Then add a `to_s` that renders the partial corresponding to the presenter
- test that the presenter returns correct values, helper returns presenter and that the `to_s` has some correct markup, controller has some correct markup
- Interesting syntax here:
{% highlight ruby %}
@columns.each_with_object({}) do |(title, attribute), memo|
{% endhighlight %}

# Chapter 7
- `request.format = :mobile` to create mobile version views (register mime type with Rails)
- Allow users to override the agent query 
- `link_to_unless`
- jQuery Mobile

# Chapter 8
- ActionMailer
- Use ASCII characters for text version of emails and provide a link to view the email
- [letter_opener gem](https://github.com/ryanb/letter_opener)

# Chapter 9
- A/B testing with [Vanity](http://vanity.labnotes.org/)
- [Deadweight gem](https://github.com/aanand/deadweight)
