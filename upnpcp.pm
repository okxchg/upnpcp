#!/usr/bin/perl
package UPnPCP;

use Getopt::Std;

use strict;
use warnings;

my $SSDP_MGROUP = '239.255.255.250';
my $SSDP_RPORT = 1900;
my $DEFAULT_MX = 3;
my $DEFAULT_TARGET = 'upnp:rootdevice';

my $scan_request = "M-SEARCH * HTTP/1.1\r\n".
                    "Host: 239.255.255.250:1900\r\n".
                    "MAN: \"ssdp:discover\"\r\n".
                    "ST: <TARGET>\r\n".
                    "MX: <MX>\r\n\r\n";
my %actions = (
    'scan' => \&scan
);

my %action_parameters = (
    'scan' => 't:m:b:r:p:n'
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
    -t timeout          Timeout in seconds (10 is default). 0 means no timeout.
                        This should be more than MX header value.
    -m timeout          SSDP MX header value. $DEFAULT_MX is default.
    -b target           Target to search for. '$DEFAULT_TARGET' is default.
    -r host             Remote host where requests will be sent. Default is 
                        multicast group '$SSDP_MGROUP', but you can also 
                        use unicast.
    -p port             Remote port on remote host. $SSDP_RPORT is default.
    -n                  Don't send anything, just print ssdp request.

EOV
}

sub scan
{
    my $opts = shift;
    my $request = $scan_request;

    # build request
    my $mx = $opts->{'m'} || $DEFAULT_MX;
    my $target = $opts->{'b'} || $DEFAULT_TARGET;
    $request =~ s/<MX>/$mx/;
    $request =~ s/<TARGET>/$target/;

    if (exists($opts->{'n'})) {
        print $request;
        return 0;
    }
}

sub parse_ssdp_response
{
     
}

1;
