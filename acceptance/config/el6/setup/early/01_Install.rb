test_name "Install packages and repositories on target machines..." do
  on hosts, "rm -rf /root/*.repo; rm -rf /root/*.rpm"
  scp_to hosts, 'repos.tar', '/root'
  on hosts, "cd /root && tar -xvf repos.tar"
  on hosts, "mv /root/*.repo /etc/yum.repos.d"
  on hosts, "rpm -Uvh --force /root/*.rpm"
  on hosts, "yum install -q -y puppet"
end
