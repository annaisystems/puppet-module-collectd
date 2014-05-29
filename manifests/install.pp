class collectd::install (
  $install_from_source = false
){
  include collectd::params
  include credis
  include yajl

  $download_command = $collectd::params::download_command
  $source_package = $collectd::params::source_package
  $source_package_url = $collectd::params::source_package_url

  case $::osfamily {
    'Debian': {
      $_install_from_source = false
      $collectd_init_src = 'contrib/upstart.collectd.conf'
      $collectd_init_dest = '/etc/init/collectd.conf'
      $collectd_init_perm = '0644'
      $build_packages = ['libcurl-dev', 'libmysqlclient-dev', 'librabbitmq-dev', 'libprotobuf-c0-dev', 'liboping-dev', 'liblvm2-dev', 'iptables-dev', 'libperl-dev']
    }
    'RedHat': {
      $_install_from_source = true
      $collectd_init_src = 'contrib/redhat/init.d-collectd'
      $collectd_init_dest = '/etc/init.d/collectd'
      $collectd_init_perm = '0755'
      $build_packages = ['libcurl-devel', 'mysql-devel', 'librabbitmq-devel', 'protobuf-c-devel', 'liboping-devel', 'lvm2-devel', 'iptables-devel', 'perl-devel']
    }
  }

  if $_install_from_source {
    package { $build_packages:
      ensure => installed,
    }
    ->
    exec { 'download collectd source':
      command => "${download_command} $source_package_url",
      cwd     => '/tmp',
      creates => "/tmp/${source_package}",
      unless  => "test -x /usr/sbin/collectd",
      notify  => Exec['extract collectd source'],
    }
    ->
    exec { 'extract collectd source':
      command => "rm -rf collectd_src && mkdir collectd_src && tar -C collectd_src --strip-components=1 -xzf ${source_package}",
      cwd     => '/tmp',
      unless  => "test -x /usr/sbin/collectd",
      notify  => Exec['configure collectd'],
    }
    ->
    exec { 'configure collectd':
      command     => "sh configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib --mandir=/usr/share/man",
      cwd         => '/tmp/collectd_src',
      refreshonly => true,
      notify      => Exec['install collectd'],
      require     => [Class['credis'] , Class['yajl']],
    }
    ->
    exec { 'install collectd':
      command     => "make all install",
      cwd         => '/tmp/collectd_src',
      refreshonly => true,
      notify      => Exec['copy collectd init script'],
    }
    ->
    exec { 'copy collectd init script':
      command     => "cp -f /tmp/collectd_src/${collectd_init_src} ${collectd_init_dest}",
      refreshonly => true,
      notify      => Exec['cleanup collectd source'],
    }
    ->
    exec { 'cleanup collectd source':
      command     => "rm -rf /tmp/collectd_src",
      refreshonly => true,
    }
    ->
    file { $collectd_init_dest:
      ensure => present,
      mode   => $collectd_init_perm,
    }
  }

  else {
    package { $package:
      ensure   => $version,
      name     => $collectd::params::package,
      provider => $collectd::params::provider,
      before   => [File['collectd.conf', 'collectd.d'], Service['collectd']]
    }
  }
}
