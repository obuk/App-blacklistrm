# -*- mode: cperl -*-
package App::blacklistrm;

our $VERSION = "0.01";

use common::sense;
#use DateTime;
use DB_File;
use Fcntl;
use Moo;
use MooX::Options protect_argv => 0, usage_string => 'USAGE: %c %o ip_address';
use Perl6::Slurp;
use Socket qw/:all/;

my $dbfile = '/var/db/blacklistd.db';
option dbfile => (
  is => 'ro', short => 'D', doc => "bdb path: $dbfile",
  format => 's', default => $dbfile,
);

option dryrun => (
  is => 'ro', short => 'd', doc => "show what happens",
);

option force => (
  is => 'ro', short => 'f',
);

option verbose => (
  is => 'rw', short => 'v',
);

sub sh {
  my $self = shift;
  say "@_" if $self->verbose;
  system @_ unless $self->dryrun;
}

sub run {
  my $self = shift->new_with_options;
  $self->options_usage(1) unless @ARGV;
  if ($self->dryrun) {
    say "# dryrun";
    $self->verbose(1);
  }
  my @ip_address = @ARGV;
  s/[^\w]/[$&]/g for @ip_address;
  my $ip_address = join '|', map "(?:$_)", @ip_address;
  my %db;
  tie %db, 'DB_File', $self->dbfile
    or tie %db, 'DB_File', $self->dbfile, O_RDONLY
    or die "DB_File: ", $self->dbfile, ": $!";
  my ($running) = grep /running/, slurp qw(-| service blacklistd status);
  $self->sh(qw/service blacklistd stop/) if $running;
  for (slurp qw(-| /usr/sbin/blacklistctl dump -awn -D), $self->dbfile) {
    my ($ipv4, $ipv6) = (qr/\d+(?:[.]\d+){3}/, qr/[\da-f]+(?:[:][\da-f]+){7}/);
    next unless my ($addr, $mask, $port) = /($ipv4|$ipv6)\/(\d+):(\d+)/;
    next unless /$ip_address/;
    my $sockaddr =
      $mask ==  32? pack_sockaddr_in  $port, inet_pton AF_INET,  $addr :
      $mask == 128? pack_sockaddr_in6 $port, inet_pton AF_INET6, $addr :
      die "can't make sockaddr: $addr/$mask";
    for (grep { $sockaddr eq substr $_, 0, unpack "C", $_ } keys %db) {
      # see /usr/src/contrib/blacklist/bin/state.[hc]
      my ($count, $lastm, $id) = unpack "l! Q Z64", $db{$_};
      if ($self->verbose) {
	#my $tz = DateTime::TimeZone->new(name => 'local');
        #my $dt = DateTime->from_epoch(epoch => $lastm, time_zone => $tz);
        my ($err, $hostname, $servicename) = getnameinfo $sockaddr;
        say "# $addr/$mask:$port $hostname:$servicename";
      }
      $db{$_} = pack "l! Q Z64", $count, 0, $id unless $self->dryrun;
      # it will be remove soon, but ...
      if ($self->force) {
        delete $db{$_} unless $self->dryrun;
        $self->sh(qw(/usr/libexec/blacklistd-helper rem blacklistd),
                  'x-proto', $addr, $mask, $port, 'x-id');
      }
    }
  }
  untie %db;
  die "untie ", $self->dbfile, ": $!; sudo?\n" if $!;
  $self->sh(qw/service blacklistd start/) if $running;
}

1;
__END__

=encoding utf-8

=head1 NAME

App::blacklistrm - something like "blacklistctl remove"

=head1 SYNOPSIS

    use App::blacklistrm;
    App::blacklistrm->run;

=head1 DESCRIPTION

=over

=item * depends on the output of blacklistctl dump -aw.

=item * blacklistd is suspended while processing.

=item * sysrc blacklistd_flags="-r" to re-read db.

=item * twists blacklist.db to remove entries.

=back

=head1 AUTHOR

KUBO, Koichi E<lt>k@obuk.orgE<gt>

=cut
