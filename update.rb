#cmd = /usr/lib/nagios/plugins/pm-plugins/portage_update/check_portage_updates.rb || (emerge -vuDaN world && emerge -v1 @preserved-rebuild && revdep-rebuild -i -p &&  /usr/local/bin/11_portage_dump_update_list.sh ;/usr/local/bin/11_portage_dump_glsa_list.sh ; /usr/lib/nagios/plugins/pm-plugins/portage_update/check_portage_updates.rb) && ls -l /proc/*/exe 2>&1 | grep deleted

require 'yaml'
require 'pony'
require "open3"
require 'erb'
require_relative "config.rb"
require_relative "services.rb"
require_relative "packages.rb"

class Updates

  def do_update_pretend_base_cmd
    "emerge -NuvpD world"
  end

  def do_update_pretend_without_blacklist_cmd 
    do_update_pretend_base_cmd + ' --exclude ' + Packages.blacklisted.join(' --exclude ')
  end

  def do_update_base_cmd
    "emerge -NuvD world"
  end

  def do_update_without_blacklist_cmd 
    do_update_base_cmd + ' --exclude ' + Packages.blacklisted.join(' --exclude ')
  end

  def all
    if @all.nil?
      stdout, stderr, status = Open3.capture3(do_update_pretend_base_cmd)
      @all = Packages.from_array(Updates.parse_update_output(stdout))
    end
    return @all
  end

  def without_blacklisted
    if @without_blacklisted.nil?
      stdout, stderr, status = Open3.capture3(do_update_pretend_without_blacklist_cmd)
      @without_blacklisted = Packages.from_array(Updates.parse_update_output(stdout))
    end
    return @without_blacklisted
  end

  def skipped
    all - without_blacklisted
  end

  def self.parse_update_output(output)
    output.split("\n").grep(/^\[ebuild/).map {|update| update}
  end
end

#save_pretend_before - for global reporting and analyzing

before_run_updates = Updates.new
puts "All updates to do: #{before_run_updates.all.count}, updates to do in this run (without blacklisted): #{before_run_updates.without_blacklisted.count}"
puts "All updates:"
before_run_updates.all.each {|package| puts package.name_version_with_slot}
puts "\nUpdates to be done:"
before_run_updates.without_blacklisted.each {|package| puts package.name_version_with_slot}
puts "\nSkipped updates:"
before_run_updates.skipped.each {|package| puts "#{package.name_version_with_slot}"}


if before_run_updates.without_blacklisted.count > 0
  stdout, stderr, status = Open3.capture3(before_run_updates.do_update_without_blacklist_cmd)

after_run_updates = Updates.new
# cfg-update
# preserved-rebuild
# revdep-rebuild
# glsa
# eselect news
stdout, stderr, status = Open3.capture3('eselect news read')
eselect_news = stdout

# restart exe missing services
services_status = Services.restart

renderer = ERB.new(File.read('./templates/mail.erb'))
mail_body = renderer.result()

puts "Run after all updates are done"
Config.instance.config['run_after'].each do |cmd|
  `#{cmd}`
end

Pony.mail({
  :from => 'updates-gentoo@power.com.pl',
  :to => 'admin@power.com.pl',
  :via => :smtp,
  :subject => "Gentoo updates report from #{`hostname`.chomp}",
  :body => mail_body,
  :attachments => {"stdout.txt" => stdout, "stderr.txt" => stderr},
  :via_options => {
    :address        => 'localhost',
    :port           => '25',
  }

})
else
  puts 'Nothing to do in this run'
end
