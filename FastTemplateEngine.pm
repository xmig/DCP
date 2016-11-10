#------------------------------------------------------------------------------
package FastTemplateEngine;

use strict;
use subs;
use Digest::MD5;


our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION, $VSSHEADER, $REVISION);

BEGIN {
    use Exporter ();

    @ISA    = qw(Exporter);
    @EXPORT = qw(
        NBSP
        EMPTY
        BLANK
        $::NBSP
        $::BLANK
        $::EMPTY

        render

        addDefaultParams
        mergeDefaultParams
        addFormater

        loadFile

        resolveTempalteName
        render_template


        setDetaults
        getUniqInt

        addRowNumber

        addTemplateFolders
        setContentFilter

        );
        %EXPORT_TAGS = (FIELDS => [@EXPORT_OK, @EXPORT]);
        $VERSION = 4.0;
        $REVISION    = '$Revision: Sergii Tretik 07-11-2016 $';
        $VSSHEADER   = '$Header: $';
    }

# Constants
#########################################################################
use constant EMPTY => '';
use constant BLANK => ' ';
use constant NBSP  => '&nbsp;';

*::NBSP  = NBSP;
*::BLANK = BLANK;
*::EMPTY = EMPTY;

our $START_TAG  = '{%';
our $STOP_TAG  = '%}';

our $PAGESIZE          = '_PAGESIZE_';
our $FIRSTPAGE         = '_FIRSTPAGE_';
our $CURRENT_PAGE_ONLY = '_CURRENT_PAGE_ONLY_';

our $PAGER_SUFFIX    = '_PAGER';
our $PAGER_PARAMETER = 'pager';

our $PACKAGE_ROOT = "DCPWX";

my $PAGESIZE          = $PAGESIZE;
my $FIRSTPAGE         = $FIRSTPAGE;
my $CURRENT_PAGE_ONLY = $CURRENT_PAGE_ONLY;

my $PAGER_SUFFIX    = $PAGER_SUFFIX;
my $PAGER_PARAMETER = $PAGER_PARAMETER;

my $content_filter = undef;

#------------------------------------------------------------------------------
sub setContentFilter {
	my ($filter) = @_;
	$content_filter = $filter;
}	


# Package's vars
#########################################################################
#my %defaultParams;

#our $CACHE_USE_TAG          = 'cache';
#our $CACHE_CHECK_TAG        = 'cache_check';
#our $SKIP_CACHE_BY_NAME_TAG = 'cache_by_name';

our %_pages_cache = ();

#our %_runtimeParams = (  $CACHE_USE_TAG          => $::SysConfig->{'DCPCache'},
#                         $CACHE_CHECK_TAG        => $::SysConfig->{'DCPCacheCheck'},
#                         $SKIP_CACHE_BY_NAME_TAG => '_notcached',
#);

# Functions
#########################################################################

sub test {
    print "DCP.test is OK. Version [$VERSION]\n";
}

#sub setCacheParameters {
#    my ($name, $value) = @_;
#    $_runtimeParams{$name} = $value;
#}
#

# Dynamic content functions
#########################################################################

#########################################################################
# addDefaultParams(%params)
# 	Setup additionals named parameters for template's processing
#########################################################################
sub addDefaultParams(%) {
    my %adds = @_;
    @::defaultParams{ keys %adds } = values %adds;
}

sub mergeDefaultParams(%) {
    my %adds = @_;
    for (keys %adds) {
        $::defaultParams{$_} = $adds{$_} unless $::defaultParams{$_};
    }
}

sub addFormater {
    my (%formaters) = @_;
    @::defaultParams{ keys %formaters } = values %formaters;
}

#------------------------------------------------------------------------------
sub addTemplateFolders {
		if (ref $_[0] eq 'ARRAY') {
			push @::tempalfolders, @{$_[0]};
		}
		else {
			push @::tempalfolders, @_;
	 }
}

sub _checksum {
    my ($rcontent) = @_;
    my $md5 = new Digest::MD5->new;

    $md5->add($_) for @$rcontent;
    return $md5->hexdigest;
}

#loadFile($filename)
#Loading file as list of lines
#Return: whole file as list of lines.
#------------------------------------------------------------------------------
sub loadFile($) {
    my ($filename) = @_;

    if (not $filename) {
        trace("File no given", undef, 1);
        return 0;
    }

    if (not open(TPL, $filename)) {
        trace("Cannot open file [$filename]", undef, 1);
        return 0;
    }

    my @result = <TPL>;
    close TPL or printLog(0, "Cannot close file [$filename].\n");
    return @result;
}

my %tagPerformers = (
    '!'       => \&_commentPerformCode,
    'comment' => \&_commentPerformCode,
    'if'      => \&_ifPerformCode,

    'iftest'  => \&_ifTestPerformCode,

    'set'      => \&_setPerformCode,

    'import'   => \&_importVarsCode,
    
    'ifempty'  => \&_ifEmptyPerformCode,
    'ifrecord' => \&_ifrecordPerformCode,


    'odd'      => \&_getOddValue,

    'ifpage'   => \&_ifpagePerformCode,
    'ifchange' => \&_changePerformCode,

    'endif'     => \&_endifPerformCode,
    'else'      => \&_elsePerformCode,
    'format'    => \&_formatPerformCode,
    'endformat' => \&_endformatPerformCode,
    
    'loop'      => \&_loopPerformCode,
    'endloop'   => \&_endloopPerformCode,

    'with'      => \&_withPerformCode,
    'endwith'   => \&_endwithPerformCode,
        
    'text'      => \&_getTextCode,
    'txt'       => \&_getTextCode,            #alias

    'textref'   => \&_getTextRefCode, 		  

    'HTML'		=> \&_getHtmlCode,            
    'html'		=> \&_getHtmlCode,            #alias
);

my %tagNeedToBeSkipped = (
    'include'   => 1,
);

my %record_conditions = (
    'even'       => '$rdi[-1]%2==0',
    'odd'        => '$rdi[-1]%2!=0',
    'inner'      => '$rdi[-1]>1 and $rdi[-1]<$rcnt[-1]',
    'first'      => '$rdi[-1]==1',
    'second'     => '$rdi[-1]==2',
    'bottompage' => '$rdi[-1]%${$pgc[-1]}[0]==0',
    'toppage'    => '($rdi[-1]-1)%${$pgc[-1]}[0]==0',
    'last'       => '$rdi[-1]==$rcnt[-1]',
    'single'     => '$rcnt[-1]==1',
);

my %page_conditions = (
    'inner'  => '$rdi[-1]>${$pgc[-1]}[0] && $rdi[-1]<${$pgc[-1]}[3]',
    'first'  => '$rdi[-1]<=${$pgc[-1]}[0]',
    'last'   => '$rdi[-1]>=${$pgc[-1]}[3]',
    'full'   => '${$pgc[-1]}[4] || $rdi[-1]<${$pgc[-1]}[3]',
    'single' => '${$pgc[-1]}[1]==1',
);


sub getCause {
    my ($param) = @_;
    my $reverce = "if";
    if ($param =~ /^not\s+(.*)/i) {
        $reverce = "unless";
        $param   = $1;
    }
    return ($param, $reverce);
}


sub update_includes {
    my ($text_content, $data, $need_to_cache, $need_resolve_template_name, $include_folder) = @_;
    my (@incl) = ($text_content =~ m/({% include\s+[\"\']([\w\.\/]+)[\"\']\s* %})/ig);
    my $i = 0;

    while ($i <= $#incl) {
        my $inc_str = $incl[$i];
        my $file    = $incl[$i + 1];

        if ($file =~ /\<#(.*?)#>/) {
            $file = $::data{$1};
        }
        my ($dir) = ($file =~ m/^([\w\/]+\/)/);

        ($file) = ($file =~ m/\/([\w\.]+)$/) if $file =~ m/\//;
        $dir =~ s/^\///;
        $dir .= "/" unless $dir =~ /\/$/;
        $dir = $include_folder . $dir;

        #print("### 1 INCLUDE. Inc [$inc_str] File: [$file] Dir: [$dir] Tempalte [$dir$file]\n");

        $data->{'SYSTEM'}{'_TEMPLATE_NAME_INCLUDED_'} = $file;

        my $tmp_page = render_template($dir . $file, $data, $need_to_cache);
        $inc_str =~ s#([\"\'\.\/])#\\\1#g;
        $text_content =~ s/$inc_str/$tmp_page/g;
        $i += 2;
    }
    return $text_content;
}

sub _code_name_normalize {
    my ($code_name) = @_;

    if ($code_name) {
        $code_name =~ s/\./_/;
        $code_name =~ s[/][__]g;
        $code_name =~ s[\\][::]g;
        $code_name =~ tr/::\.\.//d;
        $code_name =~ s/^__(.*)/$1/;
        $code_name .= "_code";
    }
    return $code_name;
}

sub _compose_full_package_filename {
    my ($base_name) = @_;
    return $PACKAGE_ROOT . "/$base_name.pm";
}

sub _compose_package_name {
    my ($code_name) = @_;
    return $PACKAGE_ROOT . "::" . $code_name;
}


sub file_updated_date {
    my ($file_name) = @_;
    return (stat($file_name))[9];
}

sub _file_cache_actual {
    my ($template_path, $code_path, $template_file_not_exists) = @_;
    if ($template_file_not_exists) {
        file_updated_date($code_path);
    }
    return file_updated_date($template_path) < file_updated_date($code_path);
}

#=============================================================================
# Render & cache Templated Content
# :$content <str or [str,]> Templated Content which will be rendered
# :$data <HASH> data for rendering
# :$need_to_cache <set of: 'memory', 'memory_only', 1, 0 > 
#    defines if compiled Template will be cached. 'memory' & 'memory_only' 
# :$template_name <str or UNDEF> Template Filename
#=============================================================================
sub render {
    my ($content, $data, $need_to_cache, $template_name) = @_;

    my $rcontent;

    if (ref $content eq 'ARRAY') {
        $rcontent = $content;
    }
    else {
        $rcontent = [$content];
    }

    my $resulted_text;
    my $code;
    my $code_name;
    my $function_name = 'go';
    my $code_file_name;
    my $fullpackage_name;
    my $function;
    my $memory_cached;
    my $file_cached;
    my $template_file_not_exists;

    if ($need_to_cache and ! $template_name) {
        $template_file_not_exists = 1;
        my $digest = _checksum($rcontent);
        $template_name = 'xauto_' . $digest;
    }
    if ($template_name) {
        $code_name          = _code_name_normalize($template_name);
        $code_file_name     = _compose_full_package_filename($code_name);
        $fullpackage_name   = _compose_package_name($code_name);
        $function_name      = $fullpackage_name . "::go";

        if ($need_to_cache) {
            if ($need_to_cache =~ /memory/i) {
                $function = $_pages_cache{$template_name};
                $memory_cached = 1 if $function;
            }
            if ($need_to_cache !~ /memory_only/i) {
                if (! $function and _file_cache_actual($template_name, $code_file_name, $template_file_not_exists)) {
                    require $code_file_name;
                    $function = eval '$' . $function_name;
                    $file_cached = 1;
                }
            }
            if ($function) {
                $resulted_text = &$function($data);
            }
        }
    }

    unless($resulted_text) {
        $code = _prepare_code($rcontent, $function_name);
        $function = eval $code;
        $resulted_text = &$function($data);
    }
    if ($need_to_cache and $template_name) {
        if (! $memory_cached and $need_to_cache =~ /memory/i) {
            $_pages_cache{$template_name} = $function;
        }
        if (! $memory_cached and ! $file_cached and $need_to_cache !~ /memory_only/i) {
            my $file_header = "package $fullpackage_name;\n";
            createPath($code_file_name, 'check');
            saveFile($code_file_name, $file_header . $code);
        }
    }

    $resulted_text = update_includes($resulted_text, $data, $need_to_cache);
    return $resulted_text;
}

#=============================================================================
# Render & cache Template
# :$template_name <str or UNDEF> Template Filename
# :$data <HASH> data for rendering
# :$need_to_cache <set of: 'memory', 'memory_only', 1, 0 > 
#    defines if compiled Template will be cached. 'memory' & 'memory_only' 
#=============================================================================
sub render_template {
    my ($template_name, $data, $need_to_cache) = @_;

    my $whole_template_name = get_temlate_name($template_name, 'resolve');
    my @content = load_template($whole_template_name);

    if (ref $content_filter eq 'CODE') {
        &$content_filter(\@content, $data);
    }

    my $current_time = time;
    $data->{'SYSTEM'} ||= {};
    $data->{'SYSTEM'}{'_TEMPLATE_NAME_'} = $template_name;
    $data->{'SYSTEM'}{'_TIMESTAMP_'}     = $current_time;
    $data->{'SYSTEM'}{'_TIMESTRING_'}    = getDateTimeString($current_time);
    $data->{'SYSTEM'}{'_TEMPLATE_NAME_FULL_'} = $whole_template_name;

    return render(\@content, $data, $need_to_cache, $whole_template_name);
}

#=============================================================================
sub remove_BOM {
    my ($file) = @_;

    my $BOM = pack 'CCC', 0xEF, 0xBB, 0xBF;
    return $file =~ /^$BOM/ ? substr ($file, length ($BOM)) : $file;
}

#=============================================================================
sub update_by_BOM_removing {
    my (@lines) = @_;

    if (scalar @lines > 0) {
        $lines[0] = remove_BOM($lines[0]);    
    }    

    return  @lines;
}

#=============================================================================
# Get Template Name
# :$template_name <str> Template Filename
#=============================================================================
sub get_temlate_name {
    my ($templatename, $need_resolve_template_name) = @_;
    my $name = $need_resolve_template_name
        ? resolveTempalteName($templatename)
        : $templatename;
}

sub load_template {
    my ($templatename) = @_;
    return update_by_BOM_removing(loadFile($templatename));
}

#=============================================================================
# Seek Template into predefined folders
# :$template_name <str> Template Filename
# GLOBAL @::tempalfolders for now
# todo = update this ^^^ - should be SYSTEM.CONFIG parameter
#=============================================================================
sub resolveTempalteName {
    my ($templatename, $nomsg) = @_;

    if ($::SysConfig->{'tarce'} and $::SysConfig->{'tarce'} > 45) {
        my $folders = join ' | ', @::tempalfolders;
        #printLog("Looking out template [$templatename] in folders [" . $folders . "]\n");
    }

    for my $dir (@::tempalfolders) {
        my $name = fullFilename($dir, $templatename);
        if (-e $name) {
            return $name;
        }
    }

    return 0 if $nomsg;

    my $folders = join ' | ', @::tempalfolders;
    my $mess = "Can not found template [$templatename] in folders [" . $folders . "]\n";
    print($mess);
}


#=============================================================================
#Pepare CODE for rendering
# :$content <str or [str,]> Templated Content which will be rendered
# :$packaged_function_name <str> function name which will be invoked for Content producing
#=============================================================================
sub _prepare_code {
    my ($rcontext, $packaged_function_name) = @_;
    my %mycontext = ();
    my @code_lines;

    foreach my $line (@$rcontext) {
        my $tag;
        my $head;
        my $tail;
        my $tbody;

        $line =~ s/\0//g;
        $line =~ s/\\/\\x5c/g;
        $line =~ s/\$/\\x24/g;
        $line =~ s/`/\\x60/g;
        $line =~ s/\@/\\x40/g;

        $line =~ s/\(/\\x28/g;
        $line =~ s/\)/\\x29/g;
        $line =~ s/\"/\\x22/g;
        $line =~ s/'/\\x27/g;

        TAILLINE:
        if ($tag) {
            $line = $tail;
            next unless $tail;
            undef $tag;
        }
				
		if ($line =~ /$START_TAG\s*(.+?)\s*$STOP_TAG/o) {
            $tag = $1;
            $head  = $`;
            $tail  = $';
            $tbody = $&;

            undef $tail if $tail =~ /^\s+\n?$/;
            my ($tag_key, $tag_param) = $tag =~ /([\w|\!]*)\s*(.*)/;
            if ($tagNeedToBeSkipped{$tag_key}) {
                goto JUSTALINE;
            }

            my $performer = $tagPerformers{$tag_key};
            #print "### TAG: [$tag] \t KEY: [$tag_key] \t PARAM: [$tag_param] \n";

            if ($performer) {
                my $tcode = &$performer($tag_param, \%mycontext);
                addCode(\@code_lines, \$head, \$tcode);
                goto TAILLINE;
            }

            addValue(\@code_lines, \$head, $tag, \%mycontext);
            goto TAILLINE;
        }
        JUSTALINE:
        addText(\@code_lines, undef, \$line);
    }

    my $code = generate_code(\@code_lines, $packaged_function_name);
    return $code;
}


#=============================================================================
# Compose PERL code which for producing rendered template
# :$rlines <LIST of strings> template -'spilt by line'
# $packaged_function_name <str> name of resulted function (usually depends on template name)
#=============================================================================
sub generate_code {
    my ($rlines, $packaged_function_name) = @_;

    my $sub_prefix = 'my';
    if ($packaged_function_name =~ /::/) {
        $sub_prefix = '';
    }

    my $last_prefix = '';
    my $timestr = getDateTimeString();
    my $rezult  = "\n### Auto generated. SimpleTemplateTranslator ver: [$VERSION] Date: [$timestr] ###\n\n";

    $rezult .= q(sub _isempt { my ($rval) = @_;
        if ($rval) {
            return eval {return $#{$rval} == -1 ? 1 : 0;};
            if ($@) {
                return trim($rval) eq '' ? 1 : 0;
            }
        }
        return 1;
    }) ."\n";

    #$rezult .= 'sub backdecode {($_) = @_; s/\&amp;/\&/g; s/\&lt;/</g; s/\&gt;/>/g; $_}' . "\n";
    $rezult .= 'sub foredecode {($_) = @_; s/\&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; $_}' . "\n";

#    $rezult .= 'sub _gval {my($tag,$rdx,@rdx)=@_;if(not $rdx->{$tag}){for my $rdx(reverse @rdx){return $rdx->{$tag} if $rdx->{$tag}}} return $rdx->{$tag}}' . "\n";

    $rezult .= 'sub _gval {my($tag,$rdx,@rdx)=@_;if(not $rdx->{$tag}){for my $rdx(reverse @rdx){return _sval($rdx->{$tag}) if $rdx->{$tag}}} return _sval($rdx->{$tag})}' . "\n";
    $rezult .= 'sub _sval {my ($val)=@_;return ref $val eq "ARRAY" ? scalar @$val : ref $val eq "HASH" ? scalar keys %$val : $val;}';

    $rezult .= "\n$sub_prefix ";
    $rezult .= '$' . $packaged_function_name . "=sub{\n";
    $rezult .= "use integer;";
    $rezult .= "my \$rdx=shift;";   # input $data HASH
    $rezult .= "my (";
    $rezult .= "\$r,";              # code buffer (result will be here)
    $rezult .= "\@rdx,";            # $data stack
    $rezult .= "\@rcnt,";           # count of elements stack
    $rezult .= "\@pgc,";            # pager stack
    $rezult .= "\@rdi,";
    $rezult .= "\@frm,";            # formatter stack
    $rezult .= "\@cntx);";          #
    $rezult .= "my \$frm=sub {\$_[1]};\n";  # current formatter

    foreach my $line (@$rlines) {
        my ($pefix, $content) = ($line =~ /(^\w+)\s{1}(.*)/s);
        $pefix 	 ||= '';    
        $content ||= '';
        next unless $content;
        if ($pefix ne $last_prefix) {
            if ($last_prefix eq '_text') {
                $rezult .= ");\n";
            }
            if ($pefix eq '_text') {
                $rezult .= "\$r.=qq($content";
            }
            else {
                $rezult .= $content;
            }
        }
        else {
            $rezult .= $content;
        }
        $last_prefix = $pefix;
    }

    if ($last_prefix eq '_text') {
        $rezult .= ");\n";
    }

    $rezult .= "return \$r;\n};\n";
    return $rezult;
}

sub addText {
    my ($rcode, $rhead, $rval) = @_;
    _addText('_text ', @_);
}

sub addCode {
    my ($rcode, $rhead, $rval) = @_;
    addText($rcode, $rhead);
    _addText('_code ', @_);
}

sub addValue {
    my ($rcode, $rhead, $tag, $rmycontext, $backdecode) = @_;

    addText($rcode, $rhead);
    my $valstr = _valstr($tag);

    #push @$rcode, '_code ' . "$valstr=backdecode($valstr);\n" if $backdecode;

    my $formater = ${ $rmycontext->{'FORMATERS'} }[-1];
    $valstr = "$formater($valstr)" if $formater;

    push @$rcode, '_vals ' . "\$r.=$valstr;\n";
}

sub _addText {
    my ($prefix, $rcode, $rhead, $rval) = @_;
    push @$rcode, $prefix . $$rhead and $$rhead = '' if defined $$rhead and $$rhead ne '';
    push @$rcode, $prefix . $$rval  and $$rval  = '' if defined $$rval  and $$rval  ne '';
}

sub _formatPerformCode {
    my ($iparam, $rmycontext) = @_;
    push @{ $rmycontext->{'FORMATERS'} }, '::' . $iparam;
    return "";
}

sub _endformatPerformCode {
    my ($iparam, $rmycontext) = @_;
    my $formater = pop @{ $rmycontext->{'FORMATERS'} };
    return "";
}

sub _getOddValue {
    return "\$r.=\$rdi[-1]%2;\n";
}

my %_def_pager = ($PAGESIZE          => 20,
                  $FIRSTPAGE         => 1,
                  $CURRENT_PAGE_ONLY => 0,
);

sub __pager {

    return [];

    my ($rglobal_dat, $rdat, $loopname, $pager_name) = @_;

    $pager_name ||= $loopname . $PAGER_SUFFIX;
    my $rpager = $rglobal_dat->{$pager_name};
    $rpager ||= \%_def_pager;
    my $rows = $#{$rdat};

    return $rows == -1 ? [] : __render_by_page($rpager, $rows);
}

#------------------------------------------------------------------------------
sub __render_by_page {
    my ($rpager, $rows) = @_;
    use integer;

    my $page_size = $rpager->{$PAGESIZE};
    return [] unless $page_size;

    my $pages_count = ($rows / $rpager->{$PAGESIZE}) + 1;

    my @pager = (
        $page_size,                                              #0 Page Size
        $pages_count,                                            #1 Pages Count
        $rpager->{$FIRSTPAGE},                                   #2 First Page
        ((($pages_count / $page_size) + 1) * $page_size) + 1,    #3 Start Last Page
        (($rows + 1) % $page_size == 0) ? 1 : 0,                 #4 All Pages is Full
        $rpager->{$CURRENT_PAGE_ONLY},                           #5 Show Current Page only
        ($page_size) * ($rpager->{$FIRSTPAGE} - 1),              #6 First row for showing (in case paging)
    );

    #printLog( "ROWS [$rows] PAGE_SIZE:($pager[0]) PAGES:($pager[1])  FIRST_PAGE:($pager[2])  LAST_PAGE_START:($pager[3])  FULL:($pager[4]) FIRST_LINE:($pager[6])\n");
    return [@pager];
}


#------------------------------------------------------------------------------
sub _withPerformCode {
    my ($iparam) = @_;

    my $tag = $iparam;
    my $rdx = '$rdx';

    ($tag, $rdx) = _get_complex_eq($tag, $rdx);
    $rdx .= '->{\'' . $tag . '\'}';

    my $code = "my \$rdt=\$rdx;";
    $code .=   "\$rdx=$rdx;\n";
    return $code;
}

#------------------------------------------------------------------------------
sub _endwithPerformCode {
    return "\$rdx=\$rdt;\n";
}

#------------------------------------------------------------------------------
sub _loopPerformCode {
    my ($iparam, $rcontext) = @_;

    my @tags = split(/\s+/, $iparam);
    my $tag = shift(@tags);

    my $code = "";
    my $pager_name;

    foreach my $tag (@tags) {
        my ($param, $value) = split('=', $tag);
        if ($param eq $PAGER_PARAMETER) {
            $pager_name = $value;
        }
    }
    my $rdx = '$rdx';
    ($tag, $rdx) = _get_complex_eq($tag, $rdx);
    $rdx .= '->{\'' . $tag . '\'}';

    #print ("\n\n+++++++++++++++++++++++++++++++++++++++++++++ rdx: [$rdx] tag: [$tag]\n\n");

    $code .= "push \@rdx,\$rdx; push \@rdi,0; push \@cntx,{}; push \@rcnt,\$#{$rdx}+1;\n";
    #$code .= "push \@pgc,DCP::DCP::getPager(\\%::data,$rdx,'$tag','$pager_name');\n";
    #$code .= "push \@pgc,FastTemplateEngine::__pager(\\%::data,$rdx,'$tag','$pager_name');\n";
    $code .= "push \@pgc,[];\n";
    $code .= "my \$rdt=$rdx;";
    $code .= 'my $st1=${$pgc[-1]}[5] ? ${$pgc[-1]}[6] : 0;';
    $code .= 'my $st2=${$pgc[-1]}[5] ? $st1+${$pgc[-1]}[0] : $#{$rdt}+1;';
    $code .= "\nfor (my \$i=\$st1; \$i<\$st2; \$i++){\$rdx=\${\$rdt}[\$i]; \$rdi[-1]++;\n";

    $code .= "last unless \$rdx;\n";
    $code .= "\$rdx = {'_'=> \$rdx} if ref(\$rdx) ne 'HASH';\n";

    # record metrics (line number, page number, ect) calculated below
    $code .= "if (\${\$pgc[-1]}[0] > 0){\n";
    $code .= "\$rdx->{'_page_'}=\${\$pgc[-1]}[5] ? \${\$pgc[-1]}[2] : (\$rdi[-1]-1)/\${\$pgc[-1]}[0]+1;\n";
    $code .= "\$rdx->{'_rid_'}=\$rdi[-1]+\$st1;\n";
    $code .= "\$rdx->{'_prid_'}=\$rdi[-1];\n";
    $code .= "\$rdx->{'_drops_'}=[('_page_','_rid_', '_prid_','_pages_','_drops_')];\n";
    $code .= "\$rdx->{'_pages_'}=\${\$pgc[-1]}[1];";
    $code .= "}\n";

    return $code;
}

#------------------------------------------------------------------------------
sub _endloopPerformCode {
    my $code = "delete \$rdx->{\$_} for \@{\$rdx->{'_drops_'}};\n";
    return $code . "}\n\$rdx=pop \@rdx; pop \@rdi; pop \@rcnt; pop \@cntx; pop \@pgc;\n";
}

sub _changePerformCode {
    my ($iparam, $rcontext) = @_;
    my ($param, $case_sym) = getCause($iparam);

    my $code = "my \$ch=\$cntx[-1]->{'TST'.'$param'} eq \$rdx->{'$param'}?0:1;\n";
    $code .= "\$cntx[-1]->{'TST'.'$param'} = \$rdx->{'$param'};\n";
    return $code . "$case_sym (\$ch){";
}

sub _ifrecordPerformCode {
    my ($param, $case_sym) = getCause(@_);
    return "$case_sym ($record_conditions{$param}){";
}

sub _ifpagePerformCode {
    my ($param, $case_sym) = getCause(@_);
    return "$case_sym ($page_conditions{$param}){";
}

#COMMENT Skip the rest of line. Only for a single lilne comments.
sub _commentPerformCode {
	my ($iparam) = @_;
    return '';
}

#------------------------------------------------------------------------------
sub _ifTestPerformCode {
	my ($iparam) = @_;
	
	my @params  = split(/\s+/, $iparam);
	my $fname = shift @params;

	my @values = ();
	push @values, '$rdx->{\'' . $_ . '\'}' for @params;
	my $values = join ',', @values;
	my $code = "if (main::$fname($values)) {";
	return $code;
}

sub _ifPerformCode {
    my ($iparam) = @_;

    my @c_or  = split(/\s*(\|{2})\s*/, $iparam);
    my @c_and = split(/\s*(\&{2})\s*/, $iparam);
    my @c = scalar @c_or > @c_and ? @c_or : @c_and;

    return __ifPerformCode('', ('&&', @c));
}

sub __ifPerformCode {
    my ($mode, @params) = @_;

    return '' if not scalar @params;
    my $cnd = shift @params;
    my $val = shift @params;

    return '' if not $val;

    my $ncond = __ifPerformCode('nc', @params);

    my $iparam = $val;

    my ($param, $case_sym) = getCause($iparam);
    my $case_eq  = $case_sym eq 'if' ? 'eq' : 'ne';
    my $case_not = $case_sym eq 'if' ? ''   : '!';

    my ($eqname, $eqval) = split('\s?==\s?', $param);

    my $rdx = '$rdx';
    ($eqname, $rdx) = _get_complex_eq($eqname, $rdx);

    #print "XXXX <$eqname> <$eqval> <$rdx>\n\n";

    if ($eqval) {
        my $value;

        if ($eqval =~ /^#/) {
            # value is a literal
            ($value) = ($eqval =~ /^#(.*)/);
            $value = "'" . $value . "'";
        }
        else {
            # value is a field name (in $data)
            if (index($eqval, '.') > 0) {
                my $rdx = '$rdx';
                ($value, $rdx) = _get_complex_eq($eqval, $rdx);
                $value = $rdx .= '{\'' . $value . '\'}';
            }
            else {
                $value = '$rdx->{\'' . $eqval . '\'}';
            }
        }
        return $mode eq 'nc'
          ? "$cnd ( _gval('$eqname', $rdx, \@rdx) $case_eq $value $ncond) "
          : "if (_gval('$eqname', $rdx, \@rdx) $case_eq $value $ncond){";
    }
    else {
        return $mode eq 'nc'
          ? "$cnd ($case_not _gval('$eqname', $rdx, \@rdx) ? 1 : 0) $ncond "
          : "if (($case_not _gval('$eqname', $rdx, \@rdx) ? 1 : 0) $ncond ){";
    }
}

sub _get_complex_eq {
    my ($tag, $rdx) = @_;
    my $eqname;

    my @varparts = split(/\./, $tag);

    for (my $i = 0; $i < $#varparts; $i++) {
        if ($varparts[$i] =~ /\[(.*?)\]/) {
            $rdx .= '->{$rdx->' . "{'$1'}}";
        }
        else {
            $rdx .= "->{'$varparts[$i]'}";
        }
    }

    $tag = $varparts[$#varparts];
    return ($tag, $rdx);
}

sub _valstr {
    my ($tag) = @_;
    my $valstr;
    my @varparts = split(/\./, $tag);

    if ($#varparts > 0) {
        $valstr = "\$rdx->{'$varparts[0]'}";
        for (my $i = 1; $i <= $#varparts; $i++) {
            if ($varparts[$i] =~ /\[(.*?)\]/) {
                $valstr .= '{$rdx->' . "{'$1'}}";
            }
            else {
                $valstr .= "{'$varparts[$i]'}";
            }
        }
    }
    else {
        $valstr = "\$rdx->{'$tag'}";
    }
    return $valstr;
}


#------------------------------------------------------------------------------
sub _getTextCode {
    my ($param) = @_;
    return "\$r.=\$::localized_msgs->{'$param'} || '';\n";
}

#ATTENTION DOES NOT support Complex names like AA.BB.CC
#------------------------------------------------------------------------------
sub _getTextRefCode {
	my ($param) = @_;
	return "my \$t=\$rdx->{'$param'};\$r.=\$::localized_msgs->{\$t} || '';\n";
}

#------------------------------------------------------------------------------
# :param <text> name of parameter.
sub _getHtmlCode {
    my ($param) = @_;
    return "\$r.=foredecode(\$rdx->{'$param'});\n";
}	


#Set command performer. Alias provider.
#Works only in 'local' context.
#------------------------------------------------------------------------------
sub _setPerformCode {
    my ($param) = @_;
    my $code = "";

    foreach my $tag (split(/\s+/, $param)) {
        my ($param, $value) = split('=', $tag);
        my $val = $value =~ /^#(.*)/ ? "'$1'" : _valstr($value);

        $code .= _valstr($param) . "=" . $val . ";";
    }

    return $code;
}

sub _importVarsCode {
    my ($param) = @_;
    my @params = split(/\s*,\s*/, $param);
    my $code;
    foreach my $p (@params) {
        $code .= __importVarsCode($p);
    }
    return $code;
}

sub __importVarsCode {
    my ($param) = @_;
    my @params = split(/\s+/, $param);
    $params[1] = $params[0] if $#params == 0;
    $params[1] = $params[2] if $params[1] eq 'as';

    return "\$rdx->{'$params[1]'}=\$rdx[-1]{'$params[0]'};\n" . "\push \@{\$rdx->{'_drops_'}}, '$params[1]';\n";
}

sub _ifEmptyPerformCode {
    my ($iparam) = @_;
    my ($param,  $case_sym) = getCause($iparam);
    return "$case_sym (_isempt(\$rdx->{'$param'})){";
}

sub _endifPerformCode {
    return "}\n";
}

sub _elsePerformCode {
    return "}else{\n";
}

sub setDetaults($$%) {
    my ($fields, $def, %dat) = @_;
    my @fields = split(',', $fields);

    foreach (@fields) {
        $dat{$_} = $def unless $dat{$_};
    }
    return %dat;
}

sub getUniqInt {
    my $tmp = rand(10000);
    $tmp =~ s/(\d+)\.\d+/$1/;
    return $tmp . time();
}


#Tools
#########################################################################
sub addRowNumber {
    my ($list, $startindex) = @_;
    my $RID_TAG   = 'RID';
    my $ODD_TAG   = 'ODD';
    my $rowNumber = defined $startindex ? $startindex : 1;

    if ($list and @$list) {
        foreach my $row (@$list) {
            $row->{$ODD_TAG} ||= $rowNumber % 2;
            $row->{$RID_TAG} ||= $rowNumber++;
        }
    }
    return $list;
}


#Utilites. Copied here - just for avoiding external references
#########################################################################
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

#------------------------------------------------------------------------------
sub saveFile {
    my ($filename, $file, $lockmode, $add_to_file) = @_;

    if ($file) {
        check_and_create_folder($filename);
        my $mode = $add_to_file ? ">>" : ">";

        if (not open OUT, "$mode$filename") {
            #logTrace("ERROR: SaveFile. File [$filename] Cannot be open. Mode: [$mode]\n");
            return 0;
        }

        if ($lockmode) {
            if (not flock(OUT, $lockmode)) {
                #logTrace("ERROR: SaveFile. File [$filename] Cannot lock file. Lockmode: [$lockmode]\n");
                return 0;
            }
        }

        binmode OUT;
        print OUT $file;
        close OUT;
        return 1;
    }
    else {
        #logTrace("ERROR: SaveFile. File [$filename] is empty. Has NOT saved!\n");
        return 0;
    }
}

#Composes full file name
#$folder folder name
#$name - short file name
#Debug: Print "debug" message if $::SysConfig->{'trace'} > 40
#Returns: resulting full file name
#------------------------------------------------------------------------------
sub fullFilename {
    my $PATH_SEPARATOR = '/';
    my ($folder, $name) = @_;
    my $sep = $folder =~ /$PATH_SEPARATOR$/ ? '' : $PATH_SEPARATOR;
    $name = substr($name, 1) if $name =~ /^$PATH_SEPARATOR/;
    return $folder . $sep . $name;
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
                mkdir $fullname;
            }
        }
    }
}


1;
__END__


