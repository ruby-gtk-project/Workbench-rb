require_relative "rb/version"

# frozen_string_literal: true

# The part of Workbench that loads without a display: just the gem's version
# constant. Unlike tally-rb, this port has no separate display-free half —
# every other file under lib/workbench reaches a widget class sooner or
# later — so spec/spec_helper.rb requires only this file and the specs ask
# for "workbench" themselves when they need the widgets.
