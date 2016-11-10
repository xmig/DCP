package DCP::LiteTime;

use strict;
use subs;
require 5.00;

our(@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

BEGIN {
	use Exporter ();
	@ISA 	= qw(Exporter);
    	@EXPORT	= qw(
    			getLocalTime
    			getDateTimeList
    			getDateTimeString

		);


    	@EXPORT_OK = qw ();
    	%EXPORT_TAGS = (FIELDS => [ @EXPORT_OK, @EXPORT ]);
    	$VERSION     = 1.01;
}


##############

sub getLocalTime {
	my $xtime = shift || time;
	my ($sec,$min,$hour) = localtime($xtime);
	#printLog(1, "TIME is ($hour :: $min :: $sec)\n");
	return $sec  + $min*60 + $hour*60*60;
}

sub getDateTimeString {
	my ($mon, $mday, $year, $hour, $min, $sec) = &getDateTimeList;
	return "$mon-$mday-$year " . $hour . ":" . $min . ":" . $sec;
}

sub getDateTimeList {
  my ($xtime) = @_;
  $xtime ||= time;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($xtime);
  $mon = $mon+1;

  $mon = '0' . $mon 	if length($mon) == 1;
  $mday = '0' . $mday 	if length($mday) == 1;

  if (length($year) == 2) {
    $year = "19$year";
  }
  else {
    my $a = substr($year, 1, 2);
    if (length($a) == 1) {
      $a = '0' . $a;
    }
    $year = "20$a";
  }

  $sec = '0' . $sec 	if length($sec) == 1;
  $min = '0' . $min 	if length($min) == 1;
  $hour = '0' . $hour 	if length($hour) == 1;

  return ($mon, $mday, $year, $hour, $min, $sec);
}


1;

