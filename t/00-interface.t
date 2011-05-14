#!/usr/bin/perl

use strict;
use warnings;

use lib '../';
use Test::More tests => 2;

use_ok('upnpcp');

eval { UPnPCP::run() };
ok($@ =~ /^Usage: upnpcp.pl <action> <OPTIONS>/);

