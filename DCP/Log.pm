#------------------------------------------------------------------------------
# $Header: /DCP/Log.pm 6     9/05/07 1:34p Mig $
# $Revision: 6 $
#------------------------------------------------------------------------------

#Set of functions for tracing / logging
#Catches "__WARN__" and "__DIE__" signals
#------------------------------------------------------------------------------
package DCP::Log;

use strict;
use subs;

our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

BEGIN {
    use Exporter ();
    use Data::Dumper;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
      setLogFile
      setLogParams
      setActionLogFile
      printLog
      printDump
      closeActionLogFile
      writeCustomCDOrder

      stderrToFile

      printError
      printTrace
      logTrace

      getDump
      logDump
      logDumpSkipSpecial

      setupDumpForHelp
      dumpForHelp

      fuction_name
      trace
      ftrace
    );
    @EXPORT_OK = qw();

    %EXPORT_TAGS = (FIELDS => [@EXPORT_OK, @EXPORT]);
    $VERSION = 2.40;

    # Error/Warn Handlers
    #------------------------------------------------------------------------------

    #
    #------------------------------------------------------------------------------
    my $pl_logfilename = eval {$0 =~ /(\w+)/; return $1} . '_PL.log';

    sub pl_printLog ($) {
        open(STREAM, ">>$pl_logfilename");
        print STREAM $_[0];
        close(STREAM);
    }
    $SIG{__WARN__} = sub {pl_printLog($_[0]);};
    $SIG{__DIE__} = sub {pl_printLog('DIE ' . $_[0]); die $_[0]};    #compile-time handler
}

$SIG{__DIE__} = sub {$::_SYSTEM_DIE_MESSAGE = 'DIE: ' . $_[0]; printLog(-1, 'DIE ' . $_[0]); die $_[0]};    #run-time handler

#Package's vars
#------------------------------------------------------------------------------
$::logfilename = eval {$0 =~ /(\w+)/; return $1} . '.log';
$::log_params = {};
my %newline_hash;

#Determinate is "Dump for Help" available. Folder where all these dumps will be collected.
#See "setupDumpForHelp" and "dumpForHelp" subs
#------------------------------------------------------------------------------
$::log_dump_for_help_path = '';

#Set up additional logging parameters
#parameter 'pid' - add PID to a log file
##parameter 'stdout' - message will be duplicated in 'STDOUT' 
#------------------------------------------------------------------------------
sub setLogParams {
    ($::log_params) = @_;
}

#Just set up file for logging
#$filename  full file name for logging
#Returns: nothing
#------------------------------------------------------------------------------
sub setLogFile($) {
    my ($filename) = @_;
    check_and_create_folder($filename);
    $::logfilename = $filename;
    $newline_hash{$::logfilename} = 1;
}

#Set up additional (suitable) log file. Remove it if one exists.
#$filename  full file name for logging
#Returns: nothing
#------------------------------------------------------------------------------
sub setActionLogFile {
    my ($filename, $params) = @_;

    $params ||= {};

    check_and_create_folder($filename);
    $::actlogfilename = $filename;

    if ( not $params->{'add'}) {   
        unlink $::actlogfilename;
    }
}



#Close additional (suitable) log file.
#------------------------------------------------------------------------------
sub closeActionLogFile {
    undef $::actlogfilename;
}

#Redirect "STREAM" stream into a file
#$logfilename full file name for logging
#Returns: nothing
#------------------------------------------------------------------------------
sub stderrToFile {
    my ($logfilename) = @_;
    open(STREAM, ">>$logfilename");
    *STDERR = *STREAM;
}

#Print 'tarce' info
#$level "INTEGER" message's level [Optional: Default - 1]
#$msg message's text
#$file full file name for logging - [Optional: Default - current log file will be used]
#Returns: nothing
#------------------------------------------------------------------------------
sub printTrace {
    my ($level, $msg, $file) = @_;

    unless ($msg) {
        $msg   = $level;
        $level = 1;
    }

    my (undef, undef, undef, $function_name) = caller(1);
    my ($package, $filename, $line, undef) = caller(0);

    my $datauid = $::DATA_UID_FOR_TRACE ? " GUID: [$::DATA_UID_FOR_TRACE]" : '';
    my $message = "\n### TRACE: Function: [$function_name] File: [$filename] Line: [$line] MESSAGE:: [$msg] Pid:[$$] $datauid\n";
    printLog($level, $message, $file);
}

#Print 'Error' info. The same as "printTrace" but message "### ERROR::" will be appeared in the beginning
#$level "INTEGER" message's level [Optional: Default - 1]
#$msg message's text
#$file full file name for logging - [Optional: Default - current log file will be used]
#Returns: nothing
#------------------------------------------------------------------------------
sub printError {
    my ($level, $msg, $file) = @_;

    unless ($msg) {
        $msg   = $level;
        $level = 1;
    }

    my (undef, undef, undef, $function_name) = caller(1);
    my ($package, $filename, $line, undef) = caller(0);

    my $prefix = "### ERROR:: Function: [$function_name] File: [$filename] Line: [$line] MESSAGE:: ";
    printLog($level, $prefix . $msg, $file);
}

#Print messages and name of function (and line #) which this particular message printed
#$msg message's text
#Returns: printed message
#------------------------------------------------------------------------------
sub logTrace {
    my ($mess) = @_;
    my (undef, undef, undef, $function_name) = caller(1);
    my ($package, $filename, $line, undef) = caller(0);

    return printLog("### $function_name [$line]\t$mess");
}

#Trace function's stack
#$mess message which will apeared in the header
#$noprint determinates if this 'trace' message will be printed
#$dept dept of function's stack which will be traced [Optional: Default - 100]
#Returns: printed message
#------------------------------------------------------------------------------
sub trace {
    my ($mess, $noprint, $dept) = @_;
    return ftrace() if not $mess;

    my $datauid = $::DATA_UID_FOR_TRACE ? " GUI: [$::DATA_UID_FOR_TRACE]" : '';
    my $result = "\nTRACE: ################################## [$mess] Pid: [$$] $datauid\n";
    my $dept ||= 100;

    for (my $i = 1; $i <= $dept; $i++) {
        my (undef, undef, undef, $function_name) = caller($i);
        my ($package, $filename, $line, undef) = caller($i - 1);

        $line = ' ' . $line while length $line < 5;

        last if not $function_name;
        $result .= "       ###$line\t$function_name\n";

    }
    return $noprint ? $result : printLog($result);
}

#Print function (and line #) which this function was invoked on "dept"
#$dept dept of function's stack which will be printed [Optional: Default - 1]
#------------------------------------------------------------------------------
sub ftrace {
    my ($dept) = @_;
    $dept ||= 1;
    my (undef, undef, undef, $function_name) = caller($dept + 1);
    my ($package, $filename, $line, undef) = caller($dept);

    my $datauid = $::DATA_UID_FOR_TRACE ? " GUID: [$::DATA_UID_FOR_TRACE]" : '';
    printLog("### TRACE: ####################### [$function_name] [$line]. Pid: [$$] $datauid\n");
}


#Returns function (and line #) which this function was invoked on "dept"
#$dept dept of function's stack which will be printed [Optional: Default - 1]
#Returns: "ARRAY" ($function_name, $line, $package, $filename);
#------------------------------------------------------------------------------
sub trace_stack {
    my ($dept) = @_;
    $dept ||= 1;
    my (undef, undef, undef, $function_name) = caller($dept + 1);
    my ($package, $filename, $line, undef) = caller($dept);
    
    return ($function_name, $line, $package, $filename);
}


#Returns invoked function name
#$dept dept of function's in stack [Optional: Default - 1]
#------------------------------------------------------------------------------
sub fuction_name {
    my ($dept) = @_;
    $dept ||= 1;
    my (undef, undef, undef, $function_name) = caller($dept);
    my @l = reverse split /::/, $function_name;
    shift @l;
}

#Print message. Only message was printed - any additional info
#$level "INTEGER" message's level [Optional: Default - 1]
#$msg message's text
#$file full file name for logging - [Optional: Default - current log file will be used]
#Returns: nothing
#------------------------------------------------------------------------------
sub printLog {
    my ($level, $msg, $file) = @_;

    unless ($msg) {
        $msg   = $level;
        $level = 1;
    }

    $file ||= $::logfilename;
    $msg = "$$\t" . $msg if $::log_params->{'pid'} && $newline_hash{$file};

    open(STREAM, ">>$file");
    print STREAM "$msg";
    close(STREAM);

    $newline_hash{$file} = substr($msg, -1, 1) eq "\n" ? 1 : 0;
    printActionLog($level, $msg);

    print "$msg" if $::log_params->{'stdout'};
}

#Print compex data into log file. Uses "printLog" for output. 
#Resulted dump is sorted.
#If you use '$logfilename' parameter please invoke this function with 3 parameters 
#$level print level. [Optional: Default - 1]. Actually does not used jet.
#$rdata "ARRAY REF" or "HASH REF" - data for dumping
#$mess message which will be appeared - title of dumping
#$logfilename name of file which this dump will be done [Optional: Default - default log file]
#Returns: nothing
#------------------------------------------------------------------------------
sub printDump {
    my ($level, $rdata, $logfilename) = @_;
    unless ($rdata) {
        $rdata = $level;
        $level = 1;
    }
    local $Data::Dumper::Sortkeys = 1;
    printLog($level, Data::Dumper->Dump([$rdata]), $logfilename);
}

#Print compex data into log file. the same as "printDump" but "Trace" info will be added
#$rdata "ARRAY REF" or "HASH REF" - data for dumping
#$mess message which will be appeared - title of dumping
#$dept of a trace which will be appeared in the beginning of the dump. [Optional: Default - 1 ] 
#$logfilename name of file which this dump will be done [Optional: Default - default log file] 
#Returns: nothing
#------------------------------------------------------------------------------
sub logDump {
    my ($rdata, $mess, $dept, $logfilename) = @_;
    $mess ||= '';
    $dept ||= 1;

    my (undef, undef, undef, $function_name) = caller($dept);
    my ($package, $filename, $line, undef) = caller($dept - 1);
    my $prefix = "### Function: [$function_name] \t[$mess]\n" . "### Package:  [$package] Filename: [$filename] Line: [$line]\n";

    local $Data::Dumper::Sortkeys = \&data_dumper_sort_default;
    printLog(1, $prefix . Data::Dumper->Dump([$rdata]), $logfilename);
    
    return;
}

#Print compex data into log file. The same as "logDump" BUT: Skip "Special" keys whiich look like  "-absd" and "_abcd"
#$rdata "ARRAY REF" or "HASH REF" - data for dumping
#$mess message which will be appeared - title of dumping
#$dept dept of dumping. Default value - dump ALL data
#Returns: nothing
#------------------------------------------------------------------------------
sub logDumpSkipSpecial {
    my ($rdata, $mess, $dept) = @_;
    $mess ||= '';
    $dept ||= 1;

    my (undef, undef, undef, $function_name) = caller($dept);
    my ($package, $filename, $line, undef) = caller($dept - 1);
    my $prefix = "### Function: [$function_name] \t[$mess]\n" . "### Package:  [$package] Filename: [$filename] Line: [$line]\n";

    local $Data::Dumper::Sortkeys = \&data_dumper_skip_special;
    printLog($prefix . Data::Dumper->Dump([$rdata]));
}

#Data Dumper Filter/Sorter
#------------------------------------------------------------------------------
sub data_dumper_skip_special {
    my ($hash) = @_;

    my @resulted;

    foreach my $k (keys %$hash) {
        push @resulted, $k if $k !~ /^[-|_]/;
    }
    return [(sort @resulted)];
}

#Data Dumper Filter/Sorter
#------------------------------------------------------------------------------
sub data_dumper_sort_default {
    my ($hash) = @_;
    return [(sort keys %$hash)];
}

#Returns "compex data" as a structured string
#$rdata "REF" data for dumping
#------------------------------------------------------------------------------
sub getDump {
    my ($rdata) = @_;

    #return Data::Dumper->Dump(ref $rdata ? $rdata : [$rdata]);
    return Data::Dumper->Dump([$rdata]);
}

#TODO: remove this function
#------------------------------------------------------------------------------
sub writeCustomCDOrder {
    my ($filename, $rdata) = @_;
    my $level = 1;
    printLog($level, Data::Dumper->Dump([$rdata]), $filename);
}

#Prind only to an additional log file
#$level "INTEGER" message lever - hasn't used yet
#$msg message for printing
#Returns: nothing
#------------------------------------------------------------------------------
sub printActionLog {
    my ($level, $msg) = @_;
    if ($::actlogfilename) {
        open(STREAM, ">>$::actlogfilename");
        print STREAM "$msg";
        close(STREAM);
    }
    return;
}

#Set up folder where "Dump for Help" will be collected
#$path - Full folder name
#Returns: nothing useful
#------------------------------------------------------------------------------
sub setupDumpForHelp {
    my ($path) = @_;
    $::log_dump_for_help_path = $path;
    return;
}

#Dump data for next parsing and generating Help/Documentation.
#Uses global var "$::log_dump_for_help_path" as a folder for dumped data storing
#Creates file with has extension '.datadump'. Uses "getDump" function for dumping
#$rdata "REF" data for dumping
#$entry_name name of entry which is dumping. Transformed into a file name.
#$comments "HASH REF" set of additional params which will be adedd to a top of a dump file.
#Returns: nothing useful
#------------------------------------------------------------------------------
sub dumpForHelp {
    my ($rdata, $entry_name, $comments) = @_;
    
    #logTrace("DUMP+FOR_HELP: [$::log_dump_for_help_path]\n");
    
    return if not $::log_dump_for_help_path;

    my $filename = $::log_dump_for_help_path;

    $filename .= '/' if not $filename =~ /[\\|\/]$/;
    $filename .= $entry_name . '.datadump';

	my ($function_name, $line, $package, $invoked_file) = trace_stack();
	unlink $filename if -e $filename;
	
	$line 			||= '???';
	$invoked_file 	||= '???';
	$package		||= '???';
	
    printLog(1, "### $package::$function_name #$line Invoked File: '$invoked_file'\n");

	#printLog("### $package::$function_name #$line Invoked File: '$invoked_file'\n", $filename);
	
	if ($comments and ref $comments eq 'HASH') {
		foreach my $k (keys %$comments) {
			printLog(1, "### '$k' => '$comments->{$k}'\n", $filename);
		}
	}
	printLog(1, "#------------------------------------------------------------------------------\n", $filename);	
    printLog(1, getDump($rdata), $filename);
    
    return;
}


#ATTENTION: This is just a copy from 'DCP::DcpUtil::check_and_create_folder'
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
#------------------------------------------------------------------------------
1;

