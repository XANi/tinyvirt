package Tinyvirt::Cluster;

use Moo;
use namespace::clean;
use Carp qw(cluck croak carp confess);

use AnyEvent;
use Log::Any qw($log);
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);


sub BUILD {
    my $self = shift;
    my $ctxt = zmq_init;
    $self->{'zmq'}{'context'} = $ctxt;
    my $cluster_tx = zmq_socket( $ctxt, ZMQ_PUB);
    my $cluster_rx = zmq_socket( $ctxt, ZMQ_SUB);
    $log->info('binding cluster zmq sockets to $self->multicast_addr');
    $self->{'zmq'}{'sock'}{'cluster-tx'} = zmq_bind( $cluster_tx, $self->multicast_addr );
    $self->{'zmq'}{'sock'}{'cluster-rx'} = zmq_connect( $cluster_rx, $self->multicast_addr );
}

# full ZMQ addr to multicast, like epgm://eth0;.238.7.6.5:5555
has multicast_addr => (
    is => 'ro',
    isa => sub {
        if ($_[0] !~ /pgm:\/\//) { croak "Need valid multicast addr like  epgm://eth0;.238.7.6.5:5555"}
    },
);


1;
