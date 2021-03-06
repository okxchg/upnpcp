#!/usr/bin/perl

use strict;
use warnings;

use lib '../';
use upnpcp;

use Test::More tests => 2;
use Test::Output;

stdout_is { UPnPCP::run('scan', '-n') } "M-SEARCH * HTTP/1.1\r\n".
                                      "Host: 239.255.255.250:1900\r\n".
                                      "MAN: \"ssdp:discover\"\r\n".
                                      "ST: upnp:rootdevice\r\n".
                                      "MX: 3\r\n\r\n";

stdout_is { 
    UPnPCP::run('scan', '-n', '-m', '40', '-b', 'target1') 
} "M-SEARCH * HTTP/1.1\r\n".
  "Host: 239.255.255.250:1900\r\n".
  "MAN: \"ssdp:discover\"\r\n".
  "ST: target1\r\n".
  "MX: 40\r\n\r\n";
