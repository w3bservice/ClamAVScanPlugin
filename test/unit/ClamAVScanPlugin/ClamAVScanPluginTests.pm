# See bottom of file for license and copyright information
use strict;
use warnings;

package ClamAVScanPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use strict;
use warnings;
use Foswiki;
use Foswiki::Plugins::ClamAVScanPlugin;
use Foswiki::Plugins::ClamAVScanPlugin::ClamAV;
use Error qw( :try );
use File::Path;

my $testfile;

my $UI_FN;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{tempdir} = $Foswiki::cfg{TempfileDir} . "/ClamAVPluginTest";

    mkdir $this->{tempdir};

    my ( $f1, $f1name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f1 <<'FL';
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore
et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum
dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui
officia deserunt mollit anim id est laborum.
FL
    $f1->close();
    $testfile = $f1name;

    my ( $f2, $f2name ) =
      File::Temp::tempfile( DIR => $this->{tempdir} )
      ;    #File::Temp::tempfile( unlink => 1 );
    print $f2 <<'FL';
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore
et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut
aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum
dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui
officia deserunt mollit anim id est laborum.
VISA, 4716204638950696, 07/11
VISA, 4111111111111111, 01/14
MasterCard, 5379100654649284, 09/11
enRoute, 214926655719613, 05/13
Discover, 6011000990139424, 02/14
American Express, 376254803268183, 09/12
VISA, 4024007135532710, 07/13
MasterCard, 5173582815239055, 10/12
Diners Club, 38520000023237, 07/11
VISA, 4024007135532710, 07/13
Discover, 6011266320013767, 06/12
American Express, 347836551942260, 10/13
FL
    $f2->close();

    $UI_FN ||= $this->getUIFn('upload');
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text("   * Set ATTACHFILESIZELIMIT = 511\n");
    $topicObject->save( forcenewrevision => 1 );

    my $query = Unit::Request->new("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->createNewFoswikiSession( undef, $query );

}

sub tear_down {
    my $this = shift;
    unlink $testfile;
    rmtree( $this->{tempdir} );
    $this->SUPER::tear_down();
}

sub test_ClamAV_ping {
    my $this      = shift;
    my $clamdPort = $Foswiki::cfg{Plugins}{ClamAVScanPlugin}{clamdPort}
      || '/tmp/clamd';

    my $av =
      new Foswiki::Plugins::ClamAVScanPlugin::ClamAV( port => "$clamdPort" );

    $this->assert_null( $av->errstr() );

    $this->assert( $av->ping );

    $av = new Foswiki::Plugins::ClamAVScanPlugin::ClamAV( port => "xxx" );

    $this->assert_null( $av->errstr() );
    $this->assert( !$av->ping );
    $this->assert_equals(
"Cannot connect to unix socket 'xxx': connect: No such file or directory",
        $av->errstr()
    );
}

sub test_ClamAV_version {
    my $this      = shift;
    my $clamdPort = $Foswiki::cfg{Plugins}{ClamAVScanPlugin}{clamdPort}
      || '/tmp/clamd';

    my $av =
      new Foswiki::Plugins::ClamAVScanPlugin::ClamAV( port => "$clamdPort" );
    my $version = $av->version();
    $this->assert_matches( qr#ClamAV (.*?)/(.*?)/(.*)#, $version );
}

sub test_ClamAV_scan_string {
    my $this = shift;

    my $clamdPort = $Foswiki::cfg{Plugins}{ClamAVScanPlugin}{clamdPort}
      || '/tmp/clamd';
    my $av =
      new Foswiki::Plugins::ClamAVScanPlugin::ClamAV( port => "$clamdPort" );

    my $text =
"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
    my ( $ok, $virus ) = $av->scan_string($text);
    $this->assert_equals( 'OK', $ok );

    # This test will only pass if ClamAV is configured for Data Loss Prevention.

    $text = <<ASDF;
VISA, 4716204638950696, 07/11
VISA, 4111111111111111, 01/14
MasterCard, 5379100654649284, 09/11
enRoute, 214926655719613, 05/13
Discover, 6011000990139424, 02/14
American Express, 376254803268183, 09/12
VISA, 4024007135532710, 07/13
MasterCard, 5173582815239055, 10/12
Diners Club, 38520000023237, 07/11
VISA, 4024007135532710, 07/13
Discover, 6011266320013767, 06/12
American Express, 347836551942260, 10/13
ASDF

    ( $ok, $virus ) = $av->scan_string($text);

    $this->assert_equals( 'FOUND',                                  $ok );
    $this->assert_equals( 'Heuristics.Structured.CreditCardNumber', $virus );
}

sub test_ClamAV_scan_stream {
    my $this = shift;

    my $clamdPort = $Foswiki::cfg{Plugins}{ClamAVScanPlugin}{clamdPort}
      || '/tmp/clamd';
    my $av =
      new Foswiki::Plugins::ClamAVScanPlugin::ClamAV( port => "$clamdPort" );

    open( my $st, '<', $testfile );

    my ( $ok, $virus ) = $av->scan_stream($st);
    $this->assert_equals( 'OK', $ok );

}

sub test_ClamAV_scan_file_or_dir {
    my $this = shift;

    my $clamdPort = $Foswiki::cfg{Plugins}{ClamAVScanPlugin}{clamdPort}
      || '/tmp/clamd';
    my $av = new Foswiki::Plugins::ClamAVScanPlugin::ClamAV(
        port      => "$clamdPort",
        find_all  => 1,
        forceScan => 0
    );

    chmod( 0777, $testfile );
    my @results = $av->scan("$testfile");

    foreach my $x (@results) {
        print STDERR "1-Results @$x[0] - @$x[1] - @$x[2] \n";
    }

    @results = $av->scan("$this->{tempdir}");

    foreach my $x (@results) {
        print STDERR "2-Results @$x[0] - @$x[1] - @$x[2] \n";
    }

}

sub do_upload {
    my ( $this, $fn, $data, $cuid, @arga ) = @_;
    my %params = @arga;
    my %args   = (
        webName   => [ $this->{test_web} ],
        topicName => [ $this->{test_topic} ],
    );
    $cuid ||= $this->{test_user_login};

    my $query = Unit::Request->new( \%args );
    $query->method('POST');
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    my $fh      = File::Temp->new();
    my $tmpfile = $fh->filename;
    print $fh $data;
    seek( $fh, 0, 0 );
    $query->param( -name => 'filepath', -value => $fn );
    my %uploads = ();
    require Foswiki::Request::Upload;
    $uploads{$fn} = Foswiki::Request::Upload->new(
        headers => {},
        tmpname => $tmpfile
    );
    $query->uploads( \%uploads );

    my $stream = $query->upload('filepath');
    $this->assert($stream);
    seek( $stream, 0, 0 );

    $this->createNewFoswikiSession( $cuid, $query );

    my $text;
    try {
        ($text) = $this->captureWithKey(
            'upload',
            sub {
                no strict 'refs';
                $UI_FN->( $this->{session} );
                use strict 'refs';
                $Foswiki::engine->finalize( $this->{session}->{response},
                    $this->{session}->{request} );
            },
            $this->{session}
        );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "clamav_upload",        $e->{def} );
        $this->assert_str_equals( "Eicar-Test-Signature", $e->{params}[1] );
        $this->assert_str_equals( "500",                  $e->{status} );
    };
    return $text;
}

sub test_simple_upload {
    my $this = shift;
    $Foswiki::cfg{Plugins}{ClamAVScanPlugin}{Enabled} = 1;

    my $data = <<'DATA';

 043-55-4485
 2241-8853-8852-4551
#X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*

DATA
    local $/ = undef;
    my $result = $this->do_upload( 'Flappadoodle.txt', $data, undef, );

    $this->assert( !$result );

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );

    # Check the meta
    my $at = $meta->get( 'FILEATTACHMENT', 'Flappadoodle.txt' );
    $this->assert( !$at );

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: GeorgeClark 

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
