#!/usr/bin/perl
use strict;
use warnings;
use Time::Piece;

my $log_file = 'transactions.log';
open my $fh, '>>', $log_file or die $!;
$fh->autoflush(1);

my @ips = ('192.168.1.1', '192.168.1.2', '10.0.0.5', '172.16.0.10');
my @users = (1, 2);

print "Generating transactions in $log_file... Press Ctrl+C to stop.\n";

while (1) {
    my $dt = localtime->strftime('%Y-%m-%d %H:%M:%S');
    my $ip = $ips[rand @ips];
    my $user = $users[rand @users];
    my $amount = sprintf("%.2f", rand(200));
    
    my $line = "[$dt] [$ip] [$user] [$amount] [RU]\n";
    print $fh $line;
    print "Generated: $line";
    
    sleep(1 + rand(2));
}
