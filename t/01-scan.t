# This is pretty horribly indented
#!/usr/bin/perl

use strict;
use warnings;

use lib '../';
use upnpcp;

use Test::More tests => 10;
use Test::Output;
use Time::HiRes qw(time);
use IO::Socket::INET;

stdout_is { UPnPCP::run('scan', '-n') } "M-SEARCH * HTTP/1.1\r\n".
                                      "Host: 239.255.255.250:1900\r\n".
                                      "MAN: \"ssdp:discover\"\r\n".
                                      "ST: upnp:rootdevice\r\n".
                                      "MX: 3\r\n\r\n";

stdout_is { 
    UPnPCP::run('scan', '-n', '-m', '40', '-b', 'target1', '-r', '1.1.1.1', '-p', '1234') 
} "M-SEARCH * HTTP/1.1\r\n".
  "Host: 1.1.1.1:1234\r\n".
  "MAN: \"ssdp:discover\"\r\n".
  "ST: target1\r\n".
  "MX: 40\r\n\r\n";

eval { UPnPCP::run('scan', '-a', '111.1.1.1111') };
ok($@ =~ /^socket: Invalid argument/);

eval { UPnPCP::run('scan', '-a', '1.1.1.1') };
ok($@ =~ /^socket: Cannot assign requested address/);

eval { UPnPCP::run('scan', '-r', '1.1.1.1111') };
ok($@ =~ /^Bad arg length for Socket::pack_sockaddr_in/);

my $time = time();
UPnPCP::run('scan', '-t', '2');
ok(int(time() - $time) == 2, 'timeout test');

# This may contain race conditions but still better than nothing
SKIP: {
    skip 'This is not linux',1 if $^O ne 'linux';

    use Socket;
    use POSIX ":sys_wait_h";

    my $ok = 0;
    my $pid = fork();
    if (!$pid) {
        # change this ip of one of your interfaces
        UPnPCP::run('scan', '-t', '3', '-a', '192.168.1.11', '-l', '1111');
        exit 0;
    } else {
        sleep(1);
        open(FILE, '/proc/net/udp') or die("Could not open /proc/net/udp: $!");

        my @netstats = <FILE>;
        shift @netstats;

        for my $line (@netstats) {
           my (undef, undef, $addr, $port) = split(/[:\s]+/, $line);
           my $ip = inet_ntoa(pack("I<*", hex($addr)));
           if ($ip eq '192.168.1.11' && hex($port) == 1111) {
                $ok = 1;
           }
        }

        waitpid($pid, 0);
        ok($ok, 'bind test');
    }
}

is_deeply(UPnPCP::parse_ssdp_response(
<<EOH
HTTP/1.1 200 OK\r
ST:upnp:rootdevice\r
Location: http://1.1.1.1:80/igd.xml\r
Server: UPnP/1.0\r
EXT:\r
EOH
), { 'HTTP/1.1 200 OK' => undef,
     'ST' => 'upnp:rootdevice',
     'LOCATION' => 'http://1.1.1.1:80/igd.xml',
     'SERVER' => 'UPnP/1.0',
     'EXT' => '',
     'DATA' => ''
}, 'parse_ssdp_response valid');

# send no location header
ok(!UPnPCP::parse_ssdp_response("HTTP/1.1 200 OK\r\n"), 
   'parse_ssdp_response invalid');

my $pid = fork();
if (!$pid) {
    sleep(1);
    my $socket = IO::Socket::INET->new( 
        Proto => 'udp', 
        PeerAddr => 'localhost', 
        PeerPort => 1900,
        LocalAddr => "127.0.0.1",
        LocalPort => 1234
    ) or die("socket: $!");

    print $socket <<EOH
HTTP/1.1 200 OK\r
Location: http://1.1.1.1:80/igd.xml\r
Server: UPnP/1.0
EOH
    ;$socket->close;
    exit 0;
} else {
    stdout_like { UPnPCP::run('scan', '-v', '-t', '3', '-l', '1900', '-a', '127.0.0.1') } 
                qr|Device \d+ at http://1\.1\.1\.1:80/igd\.xml reported from 127\.0\.0\.1:1234| 
}

