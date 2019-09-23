class mlocate::cron (
  $cron_ensure = $::mlocate::cron_ensure,
  $cron_method = $::mlocate::cron_method,
  $timer_schedule = $::mlocate::timer_schedule,
  $update_command = $::mlocate::update_command,
  $deploy_update_command = $::mlocate::deploy_update_command,
) inherits mlocate {

  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }


  # This template uses $update_command and $cron_schedule

  if $cron_method == 'cron' {

    $_real_ensure = $cron_ensure ? {
      'present' => 'file',
      'absent'  => 'absent',
      default   => 'absent',
    }

    file { '/etc/cron.d/mlocate.cron':
      ensure  => $_real_ensure,
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      content => template("${module_name}/cron.d.erb"),
    }
  } elsif $cron_method == 'timer' {

    contain ::systemd::systemctl::daemon_reload
    Class['systemd::systemctl::daemon_reload'] -> Service['mlocate-updatedb.timer']

    if $deploy_update_command {
      systemd::dropin_file{'path.conf':
        unit    => 'mlocate-updatedb.service',
        content => "#Puppet\n[Service]\nExecStart=\nExecStart=${update_command}\n",
        before  => Service['mlocate-updatedb.timer'],
      }
    }

    systemd::dropin_file{'time.conf':
      unit    => 'mlocate-updatedb.timer',
      content => "#Maintained with puppet\n[Timer]\nOnCalendar=\nOnCalendar=${timer_schedule}\n",
      notify  => Service['mlocate-updatedb.timer'],
    }

    $_real_service = $cron_ensure ? {
      'present' => true,
      'absent'  => false,
      default   => false
    }

    service{'mlocate-updatedb.timer':
      ensure => $_real_service,
      enable => $_real_service,
    }

  }
}
