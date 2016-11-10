#------------------------------------------------------------------------------
# $Header: /DCP/DcpUtil.pm 17    9/26/07 2:43p Mig $
# $Revision: 17 $
#------------------------------------------------------------------------------
package DCP::DcpUtil;

use strict;
use subs;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION, $REVISION, $VSSHEADER);

BEGIN {
    use Exporter ();
    use DCP::Log;

    @ISA    = qw(Exporter);
    @EXPORT = qw(
      trim

      getFileAsScalar
      getFileAsArray
      saveFile
      updateFile

      getBaseName
      getLatestFileName
      createPath
      check_and_create_folder

      copy_hash
      array_remove_duplicates

      format2DigitsAfterDot

      normaliseXmlItem
      normaliseXmlItemAsArray
      xmlDecode

      fullFilename
      merge_complex_data

      getFileNames

      capitalize

      composePackageFileName
      composeNextFileName

      copy_object
      
      scan_folder
      
      makePid
      removePid

      remove_BOM

    );

    @EXPORT_OK = qw (
      cap
    );

    %EXPORT_TAGS = (FIELDS => [@EXPORT_OK, @EXPORT]);
    $VERSION     = 3.22;
    $REVISION    = '$Revision: 17 $ MODIFIED';
    $VSSHEADER   = '$Header: /MUAO.NEW/spccommon/engines/stdlib/DCP/DcpUtil.pm 17    9/26/07 2:43p Mig $';
}


$::PATH_SEPARATOR = '/';
my @def_capitalize_dict = qw (Name  Type Size  Count  Value  Mode Code Data Date Order Number Line Range Price Product Shipping Info Subject Storage Company Database File);

#------------------------------------------------------------------------------
sub xmlDecode {
    my ($html) = @_;
    $html =~ s/</\&lt;/g;
    $html =~ s/\&/\&amp;/g;
    return $html;
}

#------------------------------------------------------------------------------
sub normaliseXmlItem {
    my ($item, $param) = @_;
    $param ||= 'id';
    if ($item->{$param}) {
        my $res = {};
        $res->{ $item->{$param} } = $item;
        return $res;
    }
    return $item;
}


#my $BOM = pack 'CCC', 0xEF, 0xBB, 0xBF;

#=============================================================================
sub remove_BOM {
    my ($file) = @_;

    my $BOM = pack 'CCC', 0xEF, 0xBB, 0xBF;

    return $file =~ /^$BOM/ ? substr ($file, length ($BOM)) : $file;
}


#Composes full file name
#$folder folder name
#$name - short file name
#Debug: Print "debug" message if $::SysConfig->{'trace'} > 40
#Returns: resulting full file name
#------------------------------------------------------------------------------
sub fullFilename {
    my ($folder, $name) = @_;
    my $sep = $folder =~ /$::PATH_SEPARATOR$/ ? '' : $::PATH_SEPARATOR;
    $name = substr($name, 1) if $name =~ /^$::PATH_SEPARATOR/;
    logTrace("Folder: [$folder] Separator: [$sep] Name: [$name]\n") if $::SysConfig->{'trace'} and $::SysConfig->{'trace'} > 40;
    return $folder . $sep . $name;
}

#------------------------------------------------------------------------------
sub normaliseXmlItemAsArray {
    my ($root, $item_name) = @_;

    if (not $root->{$item_name}) {
        $root->{$item_name} = [];
        return;
    }
    my @items = ref $root->{$item_name} eq 'ARRAY' ? @{ $root->{$item_name} } : ($root->{$item_name});
    $root->{$item_name} = [@items];
}

#------------------------------------------------------------------------------
sub _trim_scalar {
    my $str = shift;
    $str =~ s/\s*(.*?)\s*$/$1/;

    #printLog("TRIM  SCALAR [$str]\n");
    return $str;
}

#------------------------------------------------------------------------------
sub trim {
    my ($h) = @_;

    #printLog("TRIM [$h]\n");
    return ref $h eq 'ARRAY' ? _trim_array($h) : ref $h eq 'HASH' ? _trim_hash($h) : _trim_scalar($h);
}

#------------------------------------------------------------------------------
sub _trim_array {
    my ($h) = @_;

    my $c = scalar @$h;
    for (my $i = 0; $i < $c; $i++) {
        push @$h, trim shift @$h;
    }
    return $h;
}

#------------------------------------------------------------------------------
sub _trim_hash {
    my ($h) = @_;

    foreach my $k (keys %$h) {
        $h->{$k} = trim($h->{$k});
    }
    return $h;
}

#------------------------------------------------------------------------------
sub getFileAsScalar {
    my ($filename) = @_;
    my $result;

    if ($filename) {
        local $/ = undef;
        open IN, '<' . $filename || return 0;
        binmode IN;
        $result = <IN>;
        close IN;
    }
    return $result;
}

#------------------------------------------------------------------------------
sub getFileAsArray {
    my ($filename) = @_;
    my $handler;

    if (not open($handler, $filename)) {
        printLog(0, "Cannot open file [$filename]\n");
        return 0;
    }

    my @result = <$handler>;
    close $handler or printLog(0, "Cannot close file [$filename].\n");
    return @result;
}



#------------------------------------------------------------------------------
sub makePid {
	my ($filename) = @_;
	
	my $fh;

    if (not open $fh, ">$filename") {
       logTrace("ERROR: Cannot create Pid File \"$filename\"\n");
       return 0;
    }
	if (not flock($fh, 2|4)) { #LOCK_EX == 2 LOCK_NB == 4		
        logTrace("ERROR: Cannot lock Pid File \"$filename\"\n");
        return 0;
    }
    
    syswrite $fh, "$$\n", 100;
	return {'filehandler' => $fh, 'filename' => $filename};	 
}

#------------------------------------------------------------------------------
sub removePid {
	my ($filestruct) = @_;
	close $filestruct->{'filehandler'};
	unlink $filestruct->{'filename'};
}

#------------------------------------------------------------------------------
sub updateFile {
    my ($filename, $file) = @_;

    check_and_create_folder($filename) unless -e $filename;

    open OUT, ">>$filename" || return 0;
    binmode OUT;
    print OUT $file;
    close OUT;
    return 1;
}

sub createPath {
    my ($file_name) = @_;

    my @items = split m[/], substr $file_name, 0, rindex $file_name, '/';
    my $pach_name;

    foreach my $item (@items) {
        $pach_name .= $item . '/';
        my ($dev) = stat($pach_name);
        mkdir $pach_name unless $dev;
    }
}

#------------------------------------------------------------------------------
sub getFileNames {
    my ($dir) = @_;

    $dir ||= "./";
    opendir DIR, $dir || return undef;

    my @files = readdir(DIR);
    my @out;

    foreach my $name (sort @files) {
    	#logTrace("FILENAME: [$name]\t\t\tFOLDER: [$dir]\n");
        next if $name eq '.';
        next if $name eq '..';
        push @out, $name;
    }

    closedir(DIR);
    return @out;
}

#------------------------------------------------------------------------------
sub getLatestFileName {
    my ($fullbasefilename) = @_;

    my ($dir, $basefilename) = getBaseName($fullbasefilename);
    $dir ||= "./";

    #printLog("DIR [$dir] BASENAME: [$basefilename]\n");

    opendir DIR, $dir;
    my @files = readdir(DIR);
    shift @files;
    shift @files;

    my %timepoints;

    foreach my $filename (@files) {
        if ($filename =~ /^$basefilename/) {
            my ($timestamp) = ($filename =~ /^$basefilename(?:_*)(\d*)$/);
            $timepoints{$timestamp} = $filename;
        }
    }
    closedir(SD);

    foreach my $timestamp (reverse sort keys %timepoints) {
        return $dir . "/" . $timepoints{$timestamp};
    }
}

#Split full file name into $basename and $filename;
#$fullfilename actual file name
#Returns ($basename, $filename) "ARRAY"
#------------------------------------------------------------------------------
sub getBaseName {
    my ($fullfilename) = @_;
    my $p = rindex $fullfilename, '/';

    if ($p > 0) {
        my $basename = substr $fullfilename, 0, $p;
        my $filename = substr $fullfilename, $p + 1;
        return ($basename, $filename);
    }
    else {
        return ("", $fullfilename);
    }
}

#------------------------------------------------------------------------------
sub check_and_create_folder {
    my ($full_filename, $minitems) = @_;
    $minitems ||= 2;
    my @names = split m[/], $full_filename;
    return if $#names < $minitems;

    my $fullname;
    for my $i (0 .. scalar(@names) - 2) {
        next if not $names[$i];
        next if $names[$i] =~ /^[a-zA-Z]:/;

        $fullname .= '/' if $i;
        $fullname .= $names[$i];

        if ($fullname) {
            unless (-d $fullname) {
                printLog("CREATE FOLDER [$fullname]\n");
                mkdir $fullname;
            }
        }
    }
}

#------------------------------------------------------------------------------
sub copy_hash {
    my ($hash_in, $hash_out) = @_;
    $hash_out ||= {};

    $hash_out->{$_} = $hash_in->{$_} for keys %$hash_in;
    return $hash_out;
}

#Copy HASH. All values will be "coped" NOT "linked".
#ONLY "HASH REF" are supported for now;
#$sou "HASH REF" source for copy
#Returns: Full copy of $sou
#------------------------------------------------------------------------------
sub copy_object {
    my ($sou) = @_;

    my $tgt = {};
    foreach my $k (keys %{$sou}) {
        if (ref $sou->{$k} eq 'HASH') {
            $tgt->{$k} = copy_object($sou->{$k});
        }
        else {
            copy_hash($sou, $tgt);
        }
    }
    return $tgt;

}

#------------------------------------------------------------------------------
sub format2DigitsAfterDot {
    my $digit = trim(shift);

    return '0.00' if $digit < 0.005;

    if ($digit) {
        return $digit . '.00' if index($digit, '.') == -1;
        my ($id, $dd) = ($digit =~ /(\d+)\.+(\d+)/);
        return $id . "." . $dd . "0" if (length $dd < 2);
        $dd = substr($dd, 0, 2) if length $dd > 2;
        return $id . "." . $dd;
    }
    return 0;
}

#------------------------------------------------------------------------------
sub array_remove_duplicates {
    my $mode = ref $_[0] eq 'ARRAY' ? 'ref' : 'arr';
    my %h = map {$_ => 1} $mode eq 'ref' ? @{ $_[0] } : @_;
    return $mode eq 'ref' ? [keys %h] : keys %h;
}

#Merge HASH data recursive.
#$tgt "HASH REF" target HASH. Could be 'undef'. New empty HASH REF will be used in this case. So it will forks as a 'copy' in this case...
#$sou "HASH REF" source
#$force "SCALAR" [1 | 0 == undef] determinate if value will be updated if 'name' isn't existed in $sou Default: 0
#$uniq_only "SCALAR" [1 | 0 == undef] determinate if data merged if only TARGED key isn't existed. Default: 0
#Returns: $tgt
#------------------------------------------------------------------------------
sub merge_complex_data {
    my ($tgt, $sou, $force, $uniq_only) = @_;

    $tgt ||= {};

    foreach my $k (keys %{$sou}) {
        if (ref $tgt->{$k} eq 'HASH' and ref $sou->{$k} eq 'HASH') {
            merge_complex_data($tgt->{$k}, $sou->{$k});
        }
        else {
            if ($uniq_only) {
                if ($force) {
                    $tgt->{$k} ||= $sou->{$k};
                }
                else {
                    $tgt->{$k} ||= $sou->{$k} if defined $sou->{$k};
                }
            }
            else {
                if ($force) {
                    $tgt->{$k} = $sou->{$k};
                }
                else {
                    $tgt->{$k} = $sou->{$k} if defined $sou->{$k};
                }
            }
        }
    }
    return $tgt;
}

#String capitalization
#$mode - if $mode is "PASCAL" try to convert string into a "Pascal" view.
#$dictionary (optional) - dictionary for "Pascal" conversion. Default Dictionary - @def_capitalize_dict
#------------------------------------------------------------------------------
sub capitalize {
    my ($str, $mode, $dictionary) = @_;

    return '' if not $str;

    $str = cap($str);
    if ($mode and uc($mode) eq 'PASCAL') {
        my @dictionary = ref $dictionary eq 'ARRAY' ? @$dictionary : @def_capitalize_dict;
        foreach my $n (@dictionary) {
            $n = lc($n);
            if ($str =~ m/$n/) {
                my $v = cap($n);
                $str =~ s/$n/$v/g;
            }
        }
    }
    return $str;
}

#Just String capitalization
#------------------------------------------------------------------------------
sub cap {
    my ($str) = @_;

    return '' if not $str;

    $str = lc $str;
    my $f = uc substr($str, 0, 1);
    my $r = substr($str, 1);

    return $f . $r;
}

#$package_name "SCALAR" Package Name
#Returns: the corresponded file name. Actually it updates '::' to '/' and adds '.pm'
#------------------------------------------------------------------------------
sub composePackageFileName {
    my ($package_name) = @_;

    my @parts = split '::', $package_name;
    my $file_name = join '/', @parts;

    return $file_name . '.pm';
}

#Compose unique 'name' using suffix (.1) or (.2) or (.n)
#Returns file name (Actually full file name)
#------------------------------------------------------------------------------
sub composeNextFileName {
    my ($inname) = @_;

    my $suffix   = '';
    my $name     = $inname;
    my $maxcount = 1000;      #Just a 'safe' terminator

    my $i = 0;
    while (++$i < $maxcount) {
        $name = $name . $suffix;
        last if not -e $name;
        $suffix = ".($i)";
    }
    return $name;
}

#Recursive scan folder and execute sub for each folder item
#$dir "SCALAR" full folder name
#$sub "CODE REF" subprogram which will be executed for
#Returns: nothing useful
#Exception: if $sub isn't a "CODE REF"
#------------------------------------------------------------------------------
sub scan_folder {
	my ($dir, $sub) = @_;
	
	if (ref $sub ne 'CODE') {
		croak("The second parameter should be a code reference\n");
	}
	
	opendir DIR, $dir;
  	my @files = readdir(DIR);
  	closedir(DIR);
	
	my $xscan = sub {
		my ($mode) = @_;  
	  	foreach my $filename (@files) {
	  		next if $filename eq '.' || $filename eq '..';
	  		my $fullfilename = fullFilename($dir, $filename);
	
			if($mode eq 'd') {
		  		if (-d $fullfilename) {
	  				scan_folder($fullfilename, $sub);	
	  			}
	  		}
	  		else {	
	  			&$sub($fullfilename);
	  		}
	  	}
	};
	
	&$xscan();
	&$xscan('d');
}
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
1;
