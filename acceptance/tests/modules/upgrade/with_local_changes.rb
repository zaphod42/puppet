test_name "puppet module upgrade (with local changes)"

step 'Setup'

stub_forge_on(master)

apply_manifest_on master, <<-'MANIFEST1'
file { '/usr/share/puppet':
  ensure  => directory,
}
file { ['/etc/puppet/modules', '/usr/share/puppet/modules']:
  ensure  => directory,
  recurse => true,
  purge   => true,
  force   => true,
}
MANIFEST1
teardown do
  on master, "rm -rf /etc/puppet/modules"
  on master, "rm -rf /usr/share/puppet/modules"
end

on master, puppet("module install pmtacceptance-java --version 1.6.0")
on master, puppet("module list") do
  assert_output <<-OUTPUT
    /etc/puppet/modules
    ├── pmtacceptance-java (\e[0;36mv1.6.0\e[0m)
    └── pmtacceptance-stdlib (\e[0;36mv1.0.0\e[0m)
    /usr/share/puppet/modules (no modules installed)
  OUTPUT
end
apply_manifest_on master, <<-PP
  file {
    '/etc/puppet/modules/java/README': content => "I CHANGE MY READMES";
    '/etc/puppet/modules/java/NEWFILE': content => "I don't exist.'";
  }
PP

step "Try to upgrade a module with local changes"
on master, puppet("module upgrade pmtacceptance-java"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    STDOUT> \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in /etc/puppet/modules ...\e[0m
    STDERR> \e[1;31mError: Could not upgrade module 'pmtacceptance-java' (v1.6.0 -> latest)
    STDERR>   Installed module has had changes made locally
    STDERR>     Use `puppet module upgrade --force` to upgrade this module anyway\e[0m
  OUTPUT
end
on master, '[[ "$(cat /etc/puppet/modules/java/README)" == "I CHANGE MY READMES" ]]'
on master, '[ -f /etc/puppet/modules/java/NEWFILE ]'

step "Upgrade a module with local changes with --force"
on master, puppet("module upgrade pmtacceptance-java --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to upgrade 'pmtacceptance-java' ...\e[0m
    \e[mNotice: Found 'pmtacceptance-java' (\e[0;36mv1.6.0\e[m) in /etc/puppet/modules ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Upgrading -- do not interrupt ...\e[0m
    /etc/puppet/modules
    └── pmtacceptance-java (\e[0;36mv1.6.0 -> v1.7.1\e[0m)
  OUTPUT
end
on master, '[[ "$(cat /etc/puppet/modules/java/README)" != "I CHANGE MY READMES" ]]'
on master, '[ ! -f /etc/puppet/modules/java/NEWFILE ]'
