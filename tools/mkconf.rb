#!/usr/bin/env ruby

#
# Generate a whimsy.local version of the deployed whimsy configuration
#
# Example usage:
#  ruby vhosttest.rb <infra-puppet-checkout> | ruby mkconf.rb /private/etc/apache2/other/whimsy.conf
# or if you have ssh access to the whimsy host:
# ruby mkconf.rb /private/etc/apache2/other/whimsy.conf

if STDIN.tty?
  conf = `ssh whimsy.apache.org cat \
    /etc/apache2/sites-enabled/*-whimsy-vm-443.conf`
else
  conf = STDIN.read
end

conf = <<-EOF + conf
# generated by https://github.com/apache/whimsy/blob/master/tools/mkconf.rb
# do not edit directly.  Based on definitions found in
# https://github.com/apache/infrastructure-p6
#
EOF

conf.sub! 'SetEnv HOME /var/www',''"SetEnv HOME /var/www

# to agree with Dockerfile (ensure svn does not complain)
SetEnv LANG C.UTF-8
SetEnv LC_ALL C.UTF-8"''

conf.sub! 'VirtualHost *:443', 'VirtualHost *:1999'
conf.sub! /ServerName whimsy(.*?)\.apache\.org/, 'ServerName whimsy.local'

conf.gsub! 'ServerAlias', '## ServerAlias'

conf.gsub! /(\A|\n)\s*RemoteIPHeader.*/, ''

conf.gsub! /\n\s*PassengerDefault.*/, ''
conf.gsub! /\n\s*PassengerUser.*/, ''
conf.gsub! /\n\s*PassengerGroup.*/, ''

conf.gsub! /\n\s*SSL.*/, ''
conf.gsub! /\n\s*## SSL.*/, ''
conf.gsub! 'SetEnv HTTPS', '# SetEnv HTTPS'

conf.gsub! '/x1/srv/whimsy', '/srv/whimsy'

conf.sub! /^SetEnv PATH .*/ do |line|
  line[/PATH\s+(\/.*?):/, 1] = '/usr/local/bin'

  line
end

conf.sub! 'wss://', 'ws://'

conf.gsub! /AuthLDAPUrl .*/, 'AuthLDAPUrl "ldaps://<%= ldaphosts %>/ou=people,dc=apache,dc=org?uid"'
conf.gsub! /AuthLDAPBindDN .*/, 'AuthLDAPBindDN <%= ldapbinddn %>'
conf.gsub! /AuthLDAPBindPassword .*/, 'AuthLDAPBindPassword "<%= ldapbindpw %>"'

appendix=''"# Needs libapache2-mod-svn to be installed
# These are separate repos, as per the real ones
<Location /repos/asf>
  DAV svn
  SVNPath /srv/REPO/asf
  SetOutputFilter DEFLATE
</Location>

<Location /repos/infra>
  DAV svn
  SVNPath /srv/REPO/infra
  SetOutputFilter DEFLATE
</Location>

<Location /repos/private>
  DAV svn
  SVNPath /srv/REPO/private
  SetOutputFilter DEFLATE
</Location>

</VirtualHost>"''

conf.sub! '</VirtualHost>', appendix

conf.gsub! %r{ $}, '' # Trailing spaces

if ARGV.empty?
  puts conf
else
  ARGV.each do |arg|
    File.write arg, conf
  end
end
