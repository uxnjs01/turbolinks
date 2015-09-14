require 'turbolinks/version'
require 'turbolinks/redirection'

module Turbolinks
  module Controller
    include Redirection
  end

  class Engine < ::Rails::Engine
    config.turbolinks = ActiveSupport::OrderedOptions.new
    config.turbolinks.auto_include = true

    initializer :turbolinks do |app|
      ActiveSupport.on_load(:action_controller) do
        if app.config.turbolinks.auto_include
          include Controller
        end
      end
    end
  end
end
