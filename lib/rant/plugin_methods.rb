
require 'rant/rantlib'

# This module defines all instance methods required for an Rant
# plugin. Additionally, each plugin class has to define the class
# method +plugin_create+.
#
# Include this module in your plugin class to ensure your plugin won't
# break when Rant requires new methods.
module Rant::PluginMethods
    # The type of your plugin as string.
    def rant_plugin_type
	"rant plugin"
    end
    # Please override this method. This is used as a name for your
    # plugin instance.
    def rant_plugin_name
	"rant plugin object"
    end
    # This is used for verification. Usually you don't want to change
    # this for your plugin :-)
    def rant_plugin?
	true
    end
    # Called immediately after registration.
    def rant_plugin_init
    end
    # Called before rant runs the first task.
    def rant_start
    end
    # Called when rant *successfully* processed all required tasks.
    def rant_done
    end
    # You should "shut down" your plugin as response to this method.
    def rant_plugin_stop
    end
    # Called immediately before the rant application return control to
    # the caller.
    def rant_quit
    end
end # module Rant::PluginMethods
