#!/usr/bin/perl
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Handle;
use Time::Piece;

eval {
    require DR::Tarantool;
    require AnyEvent;
};
if ($@) {
    warn "Missing dependencies: DR::Tarantool and AnyEvent are required.\n";
}

my $log_file = shift @ARGV || 'transactions.log';
my $tnt_host = '127.0.0.1';
my $tnt_port = 3301;

unless (-e $log_file) {
    open my $nf, '>', $log_file or die $!;
    close $nf;
}

my $tnt;
sub connect_tnt {
    $tnt = DR::Tarantool->connect(
        host => $tnt_host,
        port => $tnt_port,
        cb   => sub {
            my ($instance) = @_;
            if ($instance) {
                print "Connected to Tarantool.\n";
            } else {
                warn "Failed to connect to Tarantool. Retrying in 5s...\n";
                my $w; $w = AnyEvent->timer(after => 5, cb => sub { undef $w; connect_tnt() });
            }
        }
    );
}

connect_tnt() if defined &DR::Tarantool::connect;

open my $fh, '<', $log_file or die "Could not open $log_file: $!";
seek $fh, 0, 2;

my $handle = AnyEvent::Handle->new(
    fh => $fh,
    on_error => sub { warn "Error: $_[2]\n"; $_[0]->destroy; },
);

sub read_line {
    $handle->push_read(line => sub {
        my ($hdl, $line) = @_;
        if ($line =~ /^\[(.*?)\]\s+\[(.*?)\]\s+\[(\d+)\]\s+\[([\d.]+)\]\s+\[(.*?)\]/) {
            my ($dt_str, $ip, $user_id, $amount, $geo) = ($1, $2, $3, $4, $5);
            my $ts;
            eval { $ts = Time::Piece->strptime($dt_str, '%Y-%m-%d %H:%M:%S')->epoch; };
            $ts ||= time();

            if ($tnt) {
                $tnt->call_lua(
                    'process_transaction',
                    [$user_id, $amount, $ip, $ts],
                    sub {
                        my ($res) = @_;
                        if ($res && $res->[0] && $res->[0]{status} eq 'accepted') {
                            print "User=$user_id: [ACCEPTED]\n";
                        } else {
                            my $reason = ($res && $res->[0]) ? $res->[0]{reason} : 'connection error';
                            print "User=$user_id: [REJECTED] - $reason\n";
                        }
                    }
                );
            }
        }
        read_line();
    });
}

read_line();

my $cv = AnyEvent->condvar;
my $sig = AnyEvent->signal(signal => "INT", cb => sub { $cv->send });

print "Ingester running...\n";
$cv->recv;
