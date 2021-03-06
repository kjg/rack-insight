Rack::Insight [![Dependency Status](https://gemnasium.com/pboling/rack-insight.png)](https://gemnasium.com/pboling/rack-insight) [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/pboling/rack-insight) [![Build Status](https://secure.travis-ci.org/pboling/rack-insight.png?branch=master)](https://travis-ci.org/pboling/rack-insight) [![Endorse Me](http://api.coderwall.com/pboling/endorsecount.png)](http://coderwall.com/pboling)
=============

Rack::Insight began life as an fork of Logical::Insight by LRDesign.

* I started a fork because:
    * LogicalInsight was namespaced as "Insight"
        * Causing namespace collisions everywhere I have an Insight model.  I had to re-namespace all the code.
    * I also needed to build a few extension gems with additional panels, which didn't fully work in LI
        * Added the Config class to allow for custom panel load paths
          and many other extensions that don't work in the *use Middleware* declaration.

It should be *even* easier to extend than LogicalInsight was, because extension gems can access the Config class
and truly bolt-on cleanly.

Having made really significant architectural changes, I'll be keeping Rack::Insight
a separate project for the foreseeable future.

* Forked From: [logical-insight](http://github.com/LRDesign/logical-insight)
* Which Was Forked From: [rack-bug](http://github.com/brynary/rack-bug)

Description
-----------

Rack::Insight adds a diagnostics toolbar to Rack apps. When enabled, it injects a floating div
allowing exploration of logging, database queries, template rendering times, etc.   Rack::Insight
stores debugging info over many requests, incuding AJAX requests.

Features
--------

* Password-based security
* IP-based security
* Rack::Insight instrumentation/reporting is broken up into panels.
    * Panels in default configuration:
        * Rails Info
        * Timer
        * Request Variables
        * Cache
        * Templates
        * Log               (can configure which loggers to watch!)
        * Memory
        * SQL               (Failing specs, and I don't use it, someone please pull me a fix!)
        * Active Record     (Failing specs, and I don't use it, someone please pull me a fix!)
    * Other bundled panels:
        * Sphinx (thanks to Oggy for updating this to the rack-insight panel API)
        * Redis
        * Speedtracer
    * Panels under construction:
        * Mongo
    * The API for adding your own panels is simple and very powerful
        * Consistent interface to instrument application code
        * Consistent timing across panels
        * Easy to add sub-applications for more detailed reports (c.f. SQLPanel)
        * Ask me (pboling) if you need help with this.

Build Status
---------------------------

Travis-ci: [![Build Status](https://secure.travis-ci.org/pboling/rack-insight.png?branch=master)](https://travis-ci.org/pboling/rack-insight) - Please help if you have time!

CodeClimate: [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/pboling/rack-insight)

Rails quick start
---------------------------

Add this to your Gemfile
    gem "rack-insight"

In config/environments/development.rb, add:

    config.middleware.use "Rack::Insight::App",
      :secret_key => "someverylongandveryhardtoguesspreferablyrandomstring"

Any environment with Rack::Insight loaded will have a link to "Rack::Insight" added to as
the last child of BODY to normal responses.  Clicking that link will load the
toolbar.  It's set with an id of "rack-insight-enabler", so it can be styled
to go somewhere more noticeable.  E.g. "position: absolute; top: 0; left: 0"

Using with non-Rails Rack apps
------------------------------

Just 'use Rack::Insight' as any other middleware.  See the SampleApp in the
spec/fixtures folder for an example Sinatra app.

If you wish to use the logger panel define the LOGGER constant that is a ruby
Logger or ActiveSupport::BufferedLogger

Configure Rack::Insight
---------------------

Pattern:

    Rack::Insight::Config.configure do |config|
      config[:option] = value
    end

Options:

    :logger - Can be set to any Ruby-esque Logger, examples include the Rails Logger, or the Ruby Logger (default).
            If you do not set logger Rack::Insight defaults to the Ruby Logger.
            You can configure it with additional options:
            :log_file - The logdev parameter for the Ruby Logger (a file path, an IO, like STDOUT, or STDERR, etc)
            :log_level - The maximum severity at which things should be logged.

    :rails_log_copy - If you are setting :logger to the Rails Logger, you should set this to false (default is true).

    :verbosity - true is default .
               true is equivalent to relying soley on the logger's log level to determine if a message is logged.
               Other potential values are:
                  anything falsey => no logging at all
                  Rack::Insight::Logging::VERBOSITY[*level*] where *level* is one of:
                    :debug, :high, :med, :low, :silent

    :panel_load_paths => [File::join('rack', 'insight', 'panels')] (default)
                         See *Configuring custom panels* section for example usage

    :panel_configs => This is a nested config, se below:

      Panel level configuration options for all panels, including extension gems.
      Currently this is implemented in the log_panel, and configured as:

        Rack::Insight::Config.configure do |config|
          # The following two lines have the same result
          config[:panel_configs][:log] = {:probes => {'Logger' => [:instance, :add]}}
          config[:panel_configs][:log] = {:probes => ['Logger', :instance, :add]}
        end

      Example:  If you want all of your log statements in Rails to be traced twice by Rack::Insight,
                this will do that because ActiveSupport::BufferedLogger utilizes Logger under the hood:

        config[:panel_configs][:log_panel] = {:probes => {
                "ActiveSupport::BufferedLogger" => [:instance, :add],
                "Logger" => [:instance, :add]
        }}

    :database => a hash.  Keys :raise_encoding_errors, and :raise_decoding_errors are self explanatory
                 :raise_encoding_errors
                     When set to true, if there is an encoding error (unlikely)
                     it will cause a 500 error on your site.  !!!WARNING!!!
                 :raise_decoding_errors
                     The bundled panels should work fine with :raise_decoding_errors set to true or false
                     but custom panel implementations may prefer one over the other
                     The bundled panels will capture these errors and perform admirably.
                     Site won't go down unless a custom panel is not handling the errors well.

Configure Middleware
--------------------

Specify the set of panels you want, in the order you want them to appear:

    require "rack-insight"

    ActionController::Dispatcher.middleware.use "Rack::Insight::App",
      :secret_key => "someverylongandveryhardtoguesspreferablyrandomstring",
      :panel_files => %w(
        timer_panel
        request_variables_panel
        redis_panel
        templates_panel
        cache_panel
        log_panel
        memory_panel
        sphinx_panel
      )

By default panel files are looked up by prepending "rack/insight/panels/" and requiring them.
Subclasses of Rack::Insight::Panel are loaded and added to the toolbar.  This makes
it easier to work with the configuration and extend Rack::Insight with plugin gems.

If you need to customize the load paths where Rack::Insight will look for panels you can configure the load paths in an
initializer, or in your gem prior to requiring your panels.  Example config/initializers/rack_insight.rb:

    Rack::Insight::Config.configure do |config|

      # Note: The parent directory of the 'special' directory must already be in Ruby's load path.
      config[:panel_load_paths] = File.join('special','path')

      # Example 1: Do not load any of the regular Rack::Insight panels:
      config[:panel_load_paths] = File.join('my','custom','panel','directory')

      # Example 2: Add your custom path to the existing load paths, to have your panels join the party!
      config[:panel_load_paths] << 'custom/panels'

    end

When you create custom panels use the render_template method and pass it the path to the view to be rendered
*relative to the panel load path you added above*:

    # with Example #2 from above, will try to render 'custom/panels/thunder_panel/views/thor.html.erb'
    render_template 'thunder_panel/views/thor'

Running Rack::Insight in staging or production
----------------------------------------------

We have have found that Rack::Insight is fast enough to run in production for specific troubleshooting efforts.

### Configuration ####

Add the middleware configuration to an initializer or the appropriate
environment files, taking the rest of this section into consideration.

### Security ####

Restrict access to particular IP addresses:

    require "ipaddr"

    ActionController::Dispatcher.middleware.use "Rack::Insight::App"
      :secret_key => "someverylongandveryhardtoguesspreferablyrandomstring",
      :ip_masks   => [IPAddr.new("2.2.2.2/0")]

Restrict access using a password:

    ActionController::Dispatcher.middleware.use "Rack::Insight::App",
      :secret_key => "someverylongandveryhardtoguesspreferablyrandomstring",
      :ip_masks   => false # Default is 127.0.0.1
      :password   => "yourpassword"

#### custom file path for the request recording database ####

Rack::Insight uses SQLite to store data from requests, and outputs a database
file in the root directory. If you need the file to be created at another
location (i.e. Heroku), you can pass a custom file path.

    ActionController::Dispatcher.middleware.use "Rack::Insight::App"
      :secret_key => "someverylongandveryhardtoguesspreferablyrandomstring",
      :database_path => "tmp/my_insight_db.sqlite"

Magic Panels
------------

You can now create a fully functional new panel with a simple class definition:

    module Rack::Insight
      class FooBarPanel < Panel
        self.is_magic = true
      end
    end

Setup the probes for the magic panel in a `before_initialize` block in your application.rb as follows:

    # Assuming there is a FooBra class with instance methods: foo, bar, cheese, and ducks
    Rack::Insight::Config.configure do |config|
      # Not :foo_bar_panel or 'FooBarPanel'... :foo_bar
      config[:panel_configs][:foo_bar] = {:probes => {'FooBra' => [:instance, :foo, :bar, :cheese, :ducks]}}
    end

Custom Panels
-------------

See Magic Panels above, remove the is_magic declaration, and add your own methods.
Look at the panels bundled with this gem for pointers.  Here are some important methods to watch for:

* initialize
* after_detect
* content_for_request(number)

Authors
-------

- Maintained by [Peter Boling](mailto:peter.boling@gmail.com)
- Based on LogicalInsight by Judson Lester
  - Contributions from Luke Melia, Joey Aghion, Tim Connor, and more
  - Which in turn was based on Rack::Bug by Bryan Helmkamp

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
6. Create new Pull Request

## Versioning

This library aims to adhere to [Semantic Versioning 2.0.0][semver].
Violations of this scheme should be reported as bugs. Specifically, 
if a minor or patch version is released that breaks backward 
compatibility, a new version should be immediately released that
restores compatibility. Breaking changes to the public API will 
only be introduced with new major versions.

As a result of this policy, you can (and should) specify a 
dependency on this gem using the [Pessimistic Version Constraint][pvc] with two digits of precision. 

For example:

    spec.add_dependency 'twitter', '~> 4.0'

[semver]: http://semver.org/
[pvc]: http://docs.rubygems.org/read/chapter/16#page74

Thanks
------
Rack::Insight owes a lot to both LogicalInsight and Rack::Bug, as the basis projects.  There's a lot of smart
in there.  Many thanks to Judson, and Bryan for building them.

Inspiration for Rack::Bug is primarily from the Django debug toolbar.
Additional ideas from Rails footnotes, Rack's ShowException middleware, Oink,
and Rack::Cache

License
-------

MIT. See LICENSE in this directory.

Notes
-----

The ActiveRecord panel doesn't seem to work currently.  Probably something minor, but haven't had time to look into it.

Legacy files: would like to re-include them, but they need work

    lib/rack/insight/views/panels/mongo.html.erb
    lib/rack/insight/panels/mongo_panel/mongo_extension.rb
    lib/rack/insight/panels/mongo_panel/stats.rb
    lib/rack/insight/panels/mongo_panel.rb

This one is mostly just a curiosity
    lib/rack/insight/panels/speedtracer_panel/profiling.rb
