package Tinyvirt::Cluster;
use v5.14;
use Moo;
use namespace::clean;
use Carp qw(cluck croak carp confess);

use AnyEvent;
use Log::Any qw($log);
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use UUID::Tiny ':std';

sub BUILD {
    my $self = shift;
    my $ctxt = zmq_init;
    $self->{'zmq'}{'context'} = $ctxt;
    $log->info("node uuid: " . $self->uuid);
    my $cluster_tx = zmq_socket( $ctxt, ZMQ_PUB);
    my $cluster_rx = zmq_socket( $ctxt, ZMQ_SUB);
    $log->info("binding cluster zmq sockets to " . $self->multicast_addr);
    # setup socket
    zmq_bind( $cluster_tx, $self->multicast_addr );
    zmq_connect( $cluster_rx, $self->multicast_addr );
#   zmq_bind( $cluster_tx, "ipc:///tmp/zmq");
#    zmq_connect( $cluster_rx, "ipc:///tmp/zmq");


    # subscribe to events (required, even if want all)
    zmq_setsockopt($cluster_rx, ZMQ_SUBSCRIBE, '');
    $self->{'zmq'}{'fd'}{'cluster-tx'} =  zmq_getsockopt( $cluster_tx , ZMQ_FD );
    $self->{'zmq'}{'fd'}{'cluster-rx'} =  zmq_getsockopt(  $cluster_rx , ZMQ_FD );
    $self->{'zmq'}{'sock'}{'cluster-rx'} =  $cluster_rx;
    $self->{'zmq'}{'sock'}{'cluster-tx'} =  $cluster_tx;


    $self->{'ev'}{'receiver'} = AnyEvent->io(
        fh   => $self->{'zmq'}{'fd'}{'cluster-rx'},
        poll => "r",
        cb   => sub {
            while ( my $recvmsg = zmq_recvmsg( $self->{'zmq'}{'sock'}{'cluster-rx'} , ZMQ_RCVMORE ) ) {
                my $msg = zmq_msg_data($recvmsg);
                say "someone accessed $msg";
                $log->debug("got $msg");
            }
        }
    );
    $self->{'ev'}{'ping'} = AnyEvent->timer(
        after => 1,
        interval => 2,
        cb => sub {
            my $msg = 'uuid:' . scalar $self->uuid;
            zmq_msg_send($msg, $self->{'zmq'}{'sock'}{'cluster-tx'});
        },
    );
}

# full ZMQ addr to multicast, like epgm://eth0;.238.7.6.5:5555
has multicast_addr => (
    is => 'ro',
    isa => sub {
        if ($_[0] !~ /pgm:\/\//) { croak "Need valid multicast addr like  epgm://eth0;.238.7.6.5:5555"}
    },
);

has uuid => (
    is => 'ro',
    default => sub {
        # not crypto-secure!
        create_uuid_as_string(UUID_RANDOM);
    },
);

sub parse_msg {

}

1;
