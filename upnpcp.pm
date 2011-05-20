#!/usr/bin/perl
package UPnPCP;

use strict;
use warnings;

use Socket;
use Getopt::Std;
use IO::Socket::INET;
use IO::Select;
use Time::HiRes qw(time);
use Data::Dumper;

my $SSDP_MGROUP = '239.255.255.250';
my $SSDP_RPORT = 1900;
my $DEFAULT_TIMEOUT = 10;
my $DEFAULT_MX = 3;
my $DEFAULT_TARGET = 'upnp:rootdevice';
my $MAX_RESPONSE_LEN = 9000;    

my %actions = (
    'scan' => \&scan
);

my %action_parameters = (
    'scan' => 't:m:b:r:p:na:l:v'
);


run(@ARGV) unless caller();

sub run
{
    my %opts;
    my $action = shift;
    @ARGV = @_;

    return help() if (!defined($action) || !defined($actions{"$action"}));

    getopts($action_parameters{"$action"}, \%opts);
    $actions{"$action"}->(\%opts);
}

sub help 
{
    die <<EOV
Usage: upnpcp.pl <action> <OPTIONS> 
ACTIONS:
scan

SCAN:
    -t timeout          Timeout in seconds ($DEFAULT_TIMEOUT is default). 0 means no timeout.
                        This should be more than MX header value.
    -m timeout          SSDP MX header value. $DEFAULT_MX is default.
    -b target           Target to search for. '$DEFAULT_TARGET' is default.
    -r host             Remote host where requests will be sent. Default is 
                        multicast group '$SSDP_MGROUP', but you can also 
                        use unicast.
    -p port             Remote port on remote host. $SSDP_RPORT is default.
    -a address          Bind to this address.
    -l port             Bind to this port. This is mostly used for debugging 
                        and testing.
    -n                  Don't send anything, just print ssdp request.
    -v                  Print raw ssdp responses

EOV
}

sub scan
{
    my $opts = shift;

    my $mx = $opts->{'m'} || $DEFAULT_MX;
    my $target = $opts->{'b'} || $DEFAULT_TARGET;
    my $remote_host = $opts->{'r'} || $SSDP_MGROUP;
    my $rport = $opts->{'p'} || $SSDP_RPORT;

    # build request
    my $request = "M-SEARCH * HTTP/1.1\r\n".
                  "Host: $remote_host:$rport\r\n".
                  "MAN: \"ssdp:discover\"\r\n".
                  "ST: $target\r\n".
                  "MX: $mx\r\n\r\n";

    if (exists($opts->{'n'})) {
        print $request;
        return 0;
    }

    # create socket and needed structures
    my $search_socket;
    my $response;
    my $device_num = 0;
    my $raddr = inet_aton($remote_host);
    my $sockaddr = sockaddr_in($rport, $raddr);

    $search_socket = IO::Socket::INET->new(
        LocalAddr => $opts->{'a'},
        Proto => 'udp',
        LocalPort => $opts->{'l'} 
    ) or die("socket: $!");

    $search_socket->send($request, 0, $sockaddr) or die("send: $!");

    my $select = IO::Select->new($search_socket) or die("select: $!");

    my $time;
    my $device_addr;
    my $timeout;

    if (defined($opts->{'t'})) {
        $timeout = !$opts->{'t'} ? undef : $opts->{'t'};
    } else {
        $timeout = $DEFAULT_TIMEOUT;
    }
    
    # We use select just for timeout. I think it's better to avoid 
    # using SIGALRM as it can be undefined what happens with recv
    # if it is interupted by signal.
    $time = time;
    while ($select->can_read($timeout)) {
        $device_addr = $search_socket->recv($response, $MAX_RESPONSE_LEN)
            or die("recv: $!");

        my ($port,$ip_addr) = sockaddr_in($device_addr);

        if ($opts->{'v'}) {
            print $response;
        }

        my $headers = parse_ssdp_response($response);
        if (!defined($headers)) {
            print "Device $device_num from ".inet_ntoa($ip_addr).":".$port.
                  " responded with invalid SSDP response\n";$|++;
        } else { 
            print "Device $device_num at $headers->{LOCATION} reported from ".
                   inet_ntoa($ip_addr).":".$port."\n";$|++;
        }

        $device_num++;

        if (defined($timeout)) {
            $timeout = $timeout-(time()-$time);
            $time = time();
        }
    }
}

sub parse_ssdp_response
{   
    # For now we don't care if response conforms with the UPnP standard, 
    # we are just intrested in Location header. If it is present consider 
    # response valid. This is subject to change in later releases.
    my $headers = parse_http_headers(@_);
    return undef if !$headers->{LOCATION};
    return $headers;
}

sub parse_http_headers
{
    my $raw_headers = shift;
    my %parsed_headers;
    my $i = 0;

    my @headers = split("\r\n", $raw_headers);
    for my $header(@headers) {
        $i++;
        last if (!length($header)); # End of headers
        my ($name,$value) = split(/:\s*/, $header, 2);
        $name = uc($name);
        $parsed_headers{$name} = $value;
    }
    my $lastline = @headers-1;
    $parsed_headers{DATA} = join("\n", @headers[$i..$lastline]);
    return \%parsed_headers;
}

1;
