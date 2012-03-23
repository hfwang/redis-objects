require 'rubygems'  # poor people still on 1.8
require 'pp'
gem 'redis', '>= 2.1.1'
require 'redis'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + '/../lib')
require 'bacon'
Bacon.summary_at_exit
if $0 =~ /\brspec$/
  raise "\n===\nThese tests are in bacon, not rspec.  Try: bacon #{ARGV * ' '}\n===\n"
end

UNIONSTORE_KEY = 'test:unionstore'
INTERSTORE_KEY = 'test:interstore'
DIFFSTORE_KEY  = 'test:diffstore'

# Start our own redis-server to avoid corrupting any others
REDIS_BIN  = 'redis-server'
REDIS_PORT = ENV['REDIS_PORT'] || 9212
REDIS_HOST = ENV['REDIS_HOST'] || 'localhost'
REDIS_PID  = File.expand_path 'redis.pid', File.dirname(__FILE__)
REDIS_DUMP = File.expand_path 'redis.rdb', File.dirname(__FILE__)
puts "=> Starting redis-server on #{REDIS_HOST}:#{REDIS_PORT}"
fork_pid = fork do
  system "(echo port #{REDIS_PORT}; echo logfile /dev/null; echo daemonize yes; echo pidfile #{REDIS_PID}; echo dbfilename #{REDIS_DUMP}) | #{REDIS_BIN} -"
end
at_exit do
  pid = File.read(REDIS_PID).to_i
  puts "=> Killing #{REDIS_BIN} with pid #{pid}"
  Process.kill "TERM", pid
  Process.kill "KILL", pid
  File.unlink REDIS_PID, REDIS_DUMP rescue nil
end

# Grab a global handle
$redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

SORT_ORDER = {:order => 'desc alpha'}
SORT_LIMIT = {:limit => [2, 2]}
SORT_BY = {:by => 'm_*'}
SORT_GET = {:get => 'spec/*/sorted'}.merge!(SORT_LIMIT)
SORT_STORE = {:store => "spec/aftersort"}.merge!(SORT_GET)

def count_redis_calls(redis=$redis)
  old_client = redis.client
  client = redis.client.dup
  class << client
    def reset_call_count
      @call_count = 0
    end

    def call_count
      @call_count || 0
    end

    alias_method :call_without_count, :call
    def call(*args)
      @call_count = call_count + 1
      call_without_count(*args)
    end
  end
  redis.instance_variable_set :@client, client

  yield

  redis.instance_variable_set :@client, old_client
  return client.call_count
end
