# Require core library
require 'middleman-core'
require 'middleman-navtree/version'

# Register extensions which can be activated
# Make sure we have the version of Middleman we expect
# Name param may be omited, it will default to underscored
# version of class name


::Middleman::Extensions.register(:navtree) do
    require "middleman-navtree/extension"
      ::Middleman::NavTree::NavTreeExtension
end