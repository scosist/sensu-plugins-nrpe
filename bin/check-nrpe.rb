#!/usr/bin/env ruby
# Check NRPE
# ===
#
# This is a simple NRPE check script for Sensu, We need to supply details like
# Server, port, NRPE plugin, and plugin arguments
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: nrpeclient
#
# USAGE:
#   check-nrpe -H host -c check_plugin -a 'plugin args'
#   check-nrpe -H host -c check_plugin -a 'plugin args' -m "(P|p)attern to match\.?"
#
# NOTES:
#   regex from https://github.com/naparuba/shinken/blob/master/shinken/misc/perfdata.py
#
# LICENSE:
#   Copyright (c) 2016 Scott Saunders <scosist@gmail.com>
#   Based on check-snmp.rb by Deepak Mohan Das   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'nrpeclient'

# Class that checks the return from querying NRPE.
class CheckNRPE < Sensu::Plugin::Check::CLI
  option :host,
         short: '-H host',
         boolean: true,
         default: '127.0.0.1',
         required: true

  option :check,
         short: '-c check_plugin',
         boolean: true,
         default: '',
         required: true

  option :args,
         short: '-a args',
         default: ''

  option :port,
         short: '-P port',
         description: 'port to use (default:5666)',
         default: '5666'

  option :ssl,
         short: '-S use ssl',
         description: 'enable ssl (default:true)',
         default: true

  option :match,
         short: '-m match',
         description: 'Regex pattern to match against returned buffer'

  option :comparison,
         short: '-o comparison operator',
         description: 'Operator used to compare data with warning/critial values. Can be set to "le" (<=), "ge" (>=).',
         default: 'ge'

  def run
    begin
      request = Nrpeclient::CheckNrpe.new({:host=> "#{config[:host]}", :port=> "#{config[:port]}", :ssl=> config[:ssl]})
      response = request.send_command("#{config[:check]}", "#{config[:args]}")
    rescue Errno::ETIMEDOUT
      unknown "#{config[:host]} not responding"
    rescue => e
      unknown "An unknown error occured: #{e.inspect}"
    end
    operators = { 'le' => :<=, 'ge' => :>= }
    symbol = operators[config[:comparison]]
    criticals = []
    warnings = []
    okays = []

    if config[:match]
      if response.buffer.to_s =~ /#{config[:match]}/
        ok
      else
        critical "Buffer: #{response.buffer} failed to match Pattern: #{config[:match]}"
      end
    else
      perfdata = response.buffer.split('|')[1].scan(/([^=]+=\S+)/)
      perfdata.each do |pd|
        metric = /^([^=]+)=([\d\.\-\+eE]+)([\w\/%]*);?([\d\.\-\+eE:~@]+)?;?([\d\.\-\+eE:~@]+)?;?([\d\.\-\+eE]+)?;?([\d\.\-\+eE]+)?;?\s*/.match(pd[0]) # rubocop:disable LineLength
        criticals << "Critical state detected for #{config[:check]} on #{metric[1].strip}, value: #{metric[2].to_f}#{metric[3].strip}." if "#{metric[2]}".to_f.send(symbol, "#{metric[5]}".to_f) # rubocop:disable LineLength
        # #YELLOW
        warnings << "Warning state detected for #{config[:check]} on #{metric[1].strip}, value: #{metric[2].to_f}#{metric[3].strip}." if ("#{metric[2]}".to_f.send(symbol, "#{metric[4]}".to_f)) && !("#{metric[2]}".to_f.send(symbol, "#{metric[5]}".to_f)) # rubocop:disable LineLength
        unless "#{metric[2]}".to_f.send(symbol, "#{metric[4]}".to_f)
          okays << "All is well for #{config[:check]} on #{metric[1].strip}, value: #{metric[2].to_f}#{metric[3].strip}."
        end
      end
      unless criticals.empty?
        critical criticals.join(' ')
      end
      unless warnings.empty?
        warning warnings.join(' ')
      end
      ok okays.join(' ')
    end
  end
end
