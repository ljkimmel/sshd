define sshd::sshd_settings ( $settings, $context=undef, $set_comment=true ) {
  include sshd

  validate_bool($set_comment)
  $file = $sshd::sshd_config
  $lens = $sshd::lens
  $joined_settings = join_keys_to_values($settings, ':')

  if ! $context {
    $bcontext=$file
  } else {
    $bcontext=$context
  }

  sshd::do_settings { $joined_settings:
    file        =>  $file,
    bcontext    =>  $bcontext,
    lens        =>  $lens,
    set_comment =>  $set_comment,
  }
}
