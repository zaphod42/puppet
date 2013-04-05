test_name "puppet module uninstall (with module installed)"

step "Setup"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules',
    '/etc/puppet/modules/crakorn',
  ]: ensure => directory;
  '/etc/puppet/modules/crakorn/metadata.json':
    content => '{
      "name": "jimmy/crakorn",
      "version": "0.4.0",
      "source": "",
      "author": "jimmy",
      "license": "MIT",
      "dependencies": []
    }';
}
PP
teardown do
  on master, "rm -rf /etc/puppet/modules"
end
on master, '[ -d /etc/puppet/modules/crakorn ]'

step "Uninstall the module jimmy-crakorn"
on master, puppet('module uninstall jimmy-crakorn') do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
    Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from /etc/puppet/modules
  OUTPUT
end
on master, '[ ! -d /etc/puppet/modules/crakorn ]'
