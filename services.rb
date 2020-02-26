require 'sys/proctable'
include Sys

ACTIONS = {
'/usr/sbin/apache2' => [
  {:action => '/etc/init.d/apache2 restart', :type => :service},
],
'/usr/sbin/syslog-ng' => [
  {:action => '/etc/init.d/syslog-ng restart', :type => :service},
],
'/usr/sbin/clamd' => [
  {:action => '/etc/init.d/clamd restart', :type => :service},
],
'/usr/bin/freshclam' => [
  {:action => '/etc/init.d/clamd restart', :type => :service},
],
'/usr/bin/nrpe' => [
  {:action => '/etc/init.d/nrpe restart', :type => :service},
],
'/usr/sbin/mysqld' => [
  {:action => '/etc/init.d/mysql restart', :type => :service},
],
'/usr/sbin/bacula-fd' => [
  {:action => '/etc/init.d/bacula-fd restart', :type => :service},
],
'/usr/libexec/postfix/qmgr' => [
  {:action => '/etc/init.d/postfix restart', :type => :service},
],
'/usr/sbin/haproxy' => [
  { :check => lambda {|process| process.environ.has_key?('RC_SERVICE')}, :action => lambda {|process| "#{process.environ['RC_SERVICE']} restart"}, :type => :service},
],
'/opt/icedtea-bin-3.10.0/bin/java' => [
  { :check => lambda {|process| process.environ.has_key?('RC_SERVICE')}, :action => lambda {|process| "#{process.environ['RC_SERVICE']} restart"}, :type => :service},
],
'/usr/bin/ruby24' => [
  { :check => lambda {|process| process.environ.has_key?('RC_SERVICE')}, :action => lambda {|process| "#{process.environ['RC_SERVICE']} restart"}, :type => :service},
],
'/sbin/agetty' => [
  { :check => lambda {|process| process.cmdline =~ /\/sbin\/agetty/ }, :action => lambda {|process| "kill #{process.pid}"}, :type => :command},
],
'/usr/bin/ruby25' => [
  { :check => lambda {|process| process.environ.has_key?('RC_SERVICE')}, :action => lambda {|process| "#{process.environ['RC_SERVICE']} restart"}, :type => :service},
  { :check => lambda {|process| process.cmdline == 'irb' }, :action => lambda {|process| "kill #{process.pid}"}, :type => :command},
],
'/usr/bin/containerd' => [
  {:action => '/etc/init.d/docker restart', :type => :service},
],
'/usr/bin/containerd-shim' => [
  {:action => '/etc/init.d/docker restart', :type => :service},
],
'/usr/libexec/postfix/master' => [
  {:action => '/etc/init.d/postfix restart', :type => :service},
],
'/usr/lib64/postgresql-9.6/bin/postgres' => [
  {:action => '/etc/init.d/postgresql-9.6 restart', :type => :service},
],
'/usr/bin/ssh' => [
  { :check => lambda {|process| process.cmdline.start_with?('ssh ')}, :action => lambda {|process| "kill #{process.pid}"}, :type => :user_session}
],
'/usr/sbin/sshd' => [
  { :check => lambda {|process| process.cmdline.start_with?('/usr/sbin/sshd') and process.ppid == 1}, :action => '/etc/init.d/sshd restart', :type => :service},
  { :check => lambda {|process| process.cmdline.start_with?('sshd:') and process.ppid == 1}, :action => lambda {|process| "kill #{process.pid}"}, :type => :user_session}
]
}

class Services 
  def self.restart
    processes = {:restarted => [], :unknown => []}
    actions = []
    processes[:to_restart] = ProcTable.ps.map {|process| process if process.exe =~ /.*\(deleted\)$/}.compact.uniq
    processes[:to_restart].each do |process|
      process_exe = process.exe.split.first
      if ACTIONS.has_key?(process_exe)
        process_actions = ACTIONS[process_exe]
        process_actions.each do |process_action|
          if process_action.has_key?(:check) 
            if process_action[:check].call(process)
              if process_action[:action].is_a?(Proc)
                process_action[:action].call(process)
                actions << process_action[:action].call(process)
              else
                actions << process_action[:action]
              end
            end
          else
            action = process_action[:action]
            actions <<  action
          end
        end
        processes[:restarted] << process.exe 
      else
        processes[:unknown] << process.exe
      end
    end
    actions.uniq.each do |action|
      puts "run #{action}"
      `#{action}`
    end
    return processes
  end
end

