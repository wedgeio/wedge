---
layout: default
title: Home
---

What Is Wedge
=============

Wedge was built from a desire to create an easy interface for interacting with users. With Wedge you have a lightweight set of tools to organize and present information, provide maximum code reusability, and interact between client and server actions seamlessly.

Integration
===========

Wedge currently integrates into the Roda framework. Add it to any of your apps:

Require in Bundler
------------------

{% highlight ruby %}
gem 'wedge'
{% endhighlight %}

Add To Roda
-----------

{% highlight ruby %}
class App < Roda
  plugin :wedge, {
    scope: self,
    plugins: [:form]
  }

  route do |r|
    r.wedge_assets
  end
end

App.run
{% endhighlight %}

Create Your Own Wedge Components
--------------------------------

{% highlight ruby %}
class App
  class SampleComponent < Wedge::Component
    config.name :sample

    def display
      'This is a sample component'
    end
  end
end
{% endhighlight %}

Invoke This Component In Your Route
-----------------------------------

{% highlight ruby %}
class App < Roda
  ... Roda setup goes here ...
  route do |r|
    r.wedge_assets
    r.root
      wedge(:sample).display
    end
  end
end
{% endhighlight %}
