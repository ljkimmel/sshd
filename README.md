# sshd

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup - The basics of getting started with sshd](#setup)
    * [What sshd affects](#what-sshd-affects)
4. [Usage - Configuration options and additional functionality](#usage)
    * [Caveats](#caveats)
    * [Parameters](#parameters)
    * [Facts](#facts)
    * [Defined Types](#defined-types)
    * [Examples](#examples)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

This module configures SSHD flexibly with Augeas.

## Module Description

This module configures sshd with Augeas. SSHD has numerous configuration items
and I'd prefer not to update modules frequently as options are added and removed. Using
Augeas allows the administrator to simply add arbitrary parameters at will.

The module provides a defined type (sshd_settings) that allows multiple other
classes to directly apply settings for SSHD.

The idea behind this class was to provide a simple class that takes minimal input
parameters but that still provides deep customizability of the underlying service (SSHD).

## Setup

### What sshd affects

* This module installs the SSHD package (system dependent).
* This module enables and runs the SSHD service.
* This module provides a defined type to pass a hash of setting-value
  pairs to configure SSHD.

## Usage

### Caveats

This module utilizes the standard sshd lens from Augeas. It currently only accepts simple key/
value pairs. Because of this one may need to enlist `augtool` to validate that the setting being
applied works as expected. For example, the 'Ciphers' option takes a string of comma-separated 
values (`{'Ciphers' => 'aes128-ctr,aes192-ctr,aes256-ctr'}`). However, while 'MACs' would appear
to be the same, it does not actually function that way. The lens forces each element of the comma-
separated list for this value to be a subnode. That is to say that to set the option
`MACs hmac-sha2-256,hmac-sha2-512` you actually have to pass the hash: `{'MACs/1' => 'hmac-sha2-256', 'MACs/2' => 'hmac-sha2-512'}`.

Not all options have been tested and some may not work as simple key/value pairs.

### Parameters

#### `sshd_config`
This parameter provides the full path to the SSHD configuration file.

Default: OS dependent (RHEL: /etc/ssh/sshd_config)

#### `svc_name`
This configures the name of the operating system service.

Default: OS dependent (RHEL: sshd)

#### `sshd_pkg_name`
This configures the name of the distribution package.

Default: OS dependent (RHEL: openssh-server)

#### `custom_settings`
This is a hash of key/value (setting name/setting value) to pass as the configuration.

Default: {}

#### `set_comments`
This is a boolean specifying whether or not to place a comment above each setting applied
in the sshd configuration. Since the entire file is not managed it is convenient to inform
administrators editing the file locally about the fact that certain parameters may be 
overwritten by Puppet. Setting the value to `true` will create a comment by each setting.
Setting it to `false` will remove any existing comments on passed settings.

Default: true

#### `priv_key_mode`
This specifies the permissions to configure on local sshd key files (under /etc/ssh/). The
local key files are reported by a bundled custom fact (local_ssh_priv_keys).

Default: 0600

#### `pub_key_mode`
This specifies the permissions to configure on local sshd cert files (under /etc/ssh/). The
local cert files are reported by a bundled custom fact (local_ssh_pub_keys).

Default: 0644

#### `lens`
The name of the lens to use with Augeas.

Default: sshd.lns

### Facts
#### `local_ssh_priv_keys`
Dynamically determined list of private keys under /etc/ssh.

#### `local_ssh_pub_keys`
Dynamically determined list of public keys under /etc/ssh.

### Defined Types

#### `sshd_settings`
This defined type takes in a hash of arbitrary settings (`$settings`) and applies them to the sshd configuration
file. Some care must be taken that inclusion of this type in multiple classes don't configure the same
setting. Configuring the same setting (but with differing values) will cause multiple changes during each
Puppet run and the results will be unpredictable. Passing the same setting (with same value) in multiple
classes will result in a duplicate declaration error.

The type also takes a parameter, `$context`. This parameter allows further tweaking when settings don't meet
the simple key/value paradigm. It is passed to Augeas as a 'context' so that settings can be applied at a lower level
than directly underneath the 'file'.

Finally, it also takes the `$set_comment` parameter which performs the same function as the class paramter `$set_comments`.

### Examples
This example shows a basic usage where the sshd class in declared with custom settings and then another class
uses the defined type (`sshd::sshd_settings`) to add further settings.
```puppet
  class class1 () {
    class { 'sshd':
      custom_settings => {
                         'Banner' => '/etc/issue',
                         'Protocol' => '2',
                         },
    }
  }

  class class2 () {
    sshd::sshd_settings { 'SSHD Settings required for Class2':
      settings  =>  {
                    'Ciphers' => 'aes128-ctr,aes192-ctr,aes256-ctr',
                    'MACs/1' => 'hmac-sha2-256',
                    'MACs/2' => 'hmac-sha2-512',
                    },
      }
  }
```

The defined type was also designed to ignore settings that have a nil/undef value. This is useful in cases where you have
a base class that applies to all systems and applies a default set of SSHD settings but some systems need to override one 
or more of those settings for another purpose. Here is an example that uses Hiera (hiera_hash with merging):
```yaml
  ---
  # Base Hiera data
  class1::sshd_settings:
    'Banner': '/etc/issue'
    'Protocol': '2'
    'GSSAPIAuthentication': 'no'
```

```yaml
  ---
  # Override Hiera data
  class1::sshd_settings:
    'GSSAPIAuthentication': ~

  class2::sshd_settings:
    'GSSAPIAuthentication': 'yes'
    'Ciphers': 'aes128-ctr,aes192-ctr,aes256-ctr'
    'MACs/1': 'hmac-sha2-256'
    'MACs/2': 'hmac-sha2-512'
```

```puppet
  class class1 (
    $sshd_custom_settings  = hiera_hash('class1::sshd_settings'),
  ) {
    sshd::sshd_settings { 'Class1 SSHD Settings':
      settings  =>  $sshd_custom_settings,
    }
  }

  class class2 (
    $sshd_custom_settings  = hiera_hash('class2::sshd_settings'),
  ) {
    sshd::sshd_settings { 'Class2 SSHD Settings':
      settings  =>  $sshd_custom_settings,
    }
  }
```

## Limitations

* As of 17-November-2017 this module is only built to support RHEL 6/7 as these are the
  only versions of Linux I am actively working with. I am open to adding support for 
  others if people want to provide input.
* There is no validation of configuration settings. While this allows for administrators
  to pass invalid values it is also part of the design goal of the module. Being able to
  pass arbitrary configuration settings allows the module to function across a wide range
  of sshd and OS versions without modification.
* This module was built for a limited set of purposes. The goal is to add features over time
  but it will likely occur as requested or as I find a need for something new.
* This module was built to work with Puppet 3.8 and, for the time being, needs to remain compatible. For this reason
  there is an embedded defined type within the provided defined type. This embedded type provides the ability to
  implicitly loop over the passed in settings hash.

## Development

* This is my first public module. I am eager for feedback so that I can improve this module and learn more for 
  building and releasing future modules. Please submit any feedback (good or bad) and feature requests to the module's
  GitHub issues page: https://github.com/ljkimmel/sshd/issues
* Submit issues and pull requests at: https://github.com/ljkimmel/sshd
