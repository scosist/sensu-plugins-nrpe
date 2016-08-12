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

  def run
    begin
      request = Nrpeclient::CheckNrpe.new({:host=> "#{config[:host]}", :port=> "#{config[:port]}", :ssl=> config[:ssl]})
      response = request.send_command("#{config[:check]}", "#{config[:args]}")
    rescue Errno::ETIMEDOUT
      unknown "#{config[:host]} not responding"
    rescue => e
      unknown "An unknown error occured: #{e.inspect}"
    end

    if config[:match]
      if response.buffer.to_s =~ /#{config[:match]}/
        ok
      else
        critical "Buffer: #{response.buffer} failed to match Pattern: #{config[:match]}"
      end
    else
      response_captures = response.buffer.scan(/[A-Z ]*?([A-Z]+)\s?[:-]{1}\s(.*)/)
      response_status = response_captures[0][0].downcase
      response_data = response_captures[0][1]
      case response_status
      when "critical"
        critical response_data
      when "warning"
        warning response_data
      else
        ok response_data
      end
    end
  end
end
