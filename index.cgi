#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

$:.unshift('extlib')

require 'config/config'

Dir.glob('models/*.rb').each do |filename|
  filename =~ /\Amodels\/(.*)\.rb\z/
  classname = $1
  autoload classname, filename
end

require 'controllers/blog_controller'
controller = BlogController.new
controller.handle_request()
