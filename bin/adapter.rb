# Copyright 2023 Axini B.V. https://www.axini.com, see: LICENSE.txt.
# frozen_string_literal: true

require_relative '../lib/smartdoor-ruby'

# Minimal customization through command line parameters.
if ARGV.size == 3
  name, url, token = ARGV
elsif !ARGV.empty?
  puts 'usage: adapter <name> <url> <token>'
  exit(1)
end

Adapter.new(name, url, token).run
