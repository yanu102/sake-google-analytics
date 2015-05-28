package GASake;

use strict;
use warnings;
use Carp qw/croak/;
use Mouse;
use Net::Google::Analytics;
use Net::Google::Analytics::OAuth2;

our $VERSION = '0.1';

# TODO:singletonにしたい

has 'profile_id' => (
    is  => 'rw',
    isa => 'Str'
);

has 'client_id' => (
    is  => 'rw',
    isa => 'Str'
);

has 'client_secret' => (
    is  => 'rw',
    isa => 'Str'
);

has 'refresh_access_token' => (
    is  => 'rw',
    isa => 'Str'
);

has 'request' => (
    is  => 'rw',
    isa => 'Hash'
);

sub start_date {
    my $self = shift;

    $self->{request}->{start_date} = shift;

    return $self;
}

sub end_date {
    my $self = shift;

    $self->{request}->{end_date} = shift;

    return $self;
}

sub reviewed_sake_ids {
    my $self = shift;

    if (   $self->{profile_id} eq q{}
        || $self->{client_id} eq q{}
        || $self->{client_secret} eq q{}
        || $self->{refresh_access_token} eq q{} )
    {
        return ();
    }

    my $analytics = Net::Google::Analytics->new;

    my $oauth = Net::Google::Analytics::OAuth2->new(
        client_id     => $self->{client_id},
        client_secret => $self->{client_secret}
    );
    my $token = $oauth->refresh_access_token( $self->{refresh_access_token} );
    $analytics->token($token);

    my $profile_id = 'ga:' . $self->{profile_id};
    my @request = ( 'ids' => $profile_id );
    push @request, %{ $self->{request} };
    my $req = $analytics->new_request(@request);

    my $res = $analytics->retrieve($req);
    croak 'GA error: ' . $res->error_message if !$res->is_success;

    my @ids;
    for my $row ( @{ $res->rows } ) {
        push @ids, $row->get_event_label;
    }

    return @ids;
}

1;
