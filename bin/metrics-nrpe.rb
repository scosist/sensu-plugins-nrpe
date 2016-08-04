#!/usr/bin/env ruby
# NRPE Metrics
# ===
#
# This is a simple script to collect metrics from an NRPE plugin
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: nrpeclient
#
# USAGE:
#   check-nrpe -H host -c check_plugin -a 'plugin args' -p prefix -s suffix
#
# NOTES:
#   regex from https://github.com/naparuba/shinken/blob/master/shinken/misc/perfdata.py
#
# LICENSE:
#   Copyright (c) 2016 Scott Saunders <scosist@gmail.com>
#   Based on metrics-snmp.rb by Double Negative Limited
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/metric/cli'
require 'nrpeclient'

# Class that collects and outputs NRPE metrics in graphite format
class NRPEGraphite < Sensu::Plugin::Metric::CLI::Graphite
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

  option :prefix,
         short: '-p prefix',
         description: 'prefix to attach to graphite path'

  option :suffix,
         short: '-s suffix',
         description: 'suffix to attach to graphite path',
         required: true

  option :port,
         short: '-P port',
         description: 'port to use (default:5666)',
         default: '5666'

  option :ssl,
         short: '-S use ssl',
         description: 'enable ssl (default:true)',
         default: true

  option :graphite,
         short: '-g',
         description: 'Replace dots with underscores in hostname',
         boolean: true

  def run
    begin
      request = Nrpeclient::CheckNrpe.new({:host=> "#{config[:host]}", :port=> "#{config[:port]}", :ssl=> config[:ssl]})
      response = request.send_command("#{config[:check]}", "#{config[:args]}")
    rescue Errno::ETIMEDOUT
      unknown "#{config[:host]} not responding"
    rescue => e
      unknown "An unknown error occured: #{e.inspect}"
    end
    config[:host] = config[:host].gsub('.', '_') if config[:graphite]
    perfdata = response.buffer.split('|')[1].scan(/([^=]+=\S+)/)
    perfdata.each do |pd|
      metric = /^([^=]+)=([\d\.\-\+eE]+)([\w\/%]*);?([\d\.\-\+eE:~@]+)?;?([\d\.\-\+eE:~@]+)?;?([\d\.\-\+eE]+)?;?([\d\.\-\+eE]+)?;?\s*/.match(pd[0]) # rubocop:disable LineLength
      if config[:prefix]
        output "#{config[:prefix]}.#{config[:host]}.#{config[:suffix]}.#{metric[1].strip}", metric[2].to_f
      else
        output "#{config[:host]}.#{config[:suffix]}.#{metric[1].strip}", metric[2].to_f
      end
    end
    ok
  end
end
