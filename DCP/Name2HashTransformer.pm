#------------------------------------------------------------------------------
# $Header: /DCP/Name2HashTransformer.pm 5     9/11/07 4:08p Mig $
# $Revision: 5 $
#------------------------------------------------------------------------------
package DCP::Name2HashTransformer;
use strict;

#------------------------------------------------------------------------------
our (@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION, $REVISION, $VSSHEADER);

BEGIN {
    use Exporter ();
    use DCP::Log;

    @EXPORT = qw(
    );

    @EXPORT_OK = qw (
      isComplexName
      updateComplexParameter
      
      updateComplexProperties
      getValueByComplexName
    );

    $VERSION = 1.01;

    %EXPORT_TAGS = (FIELDS => [@EXPORT_OK, @EXPORT]);
    $REVISION    = '$Revision: 5 $';
    $VSSHEADER   = '$Header: /MUAO.NEW/spccommon/engines/stdlib/DCP/Name2HashTransformer.pm 5     9/11/07 4:08p Mig $';

}

#Check if a name is complex (contains dot in within a name)
#------------------------------------------------------------------------------
sub isComplexName {
    my ($name) = @_;
    return $name =~ /\./ ? 1 : 0;
}


#Transform complex properties to HASH. Scan and chack all names from $source. Complex valies stored into $root as a HASH
#$root - target reference (HASH)
#$source - source reference (HASH)  Optional -> default == $root
#------------------------------------------------------------------------------
sub updateComplexProperties {
	my ($source, $root) = @_;
	
	$root ||= $source;
	
	return undef if ref $root ne 'HASH' || ref $source ne 'HASH';
	
	foreach my $name (keys %$source) {
		next if not DCP::Name2HashTransformer::isComplexName($name);
		updateComplexParameter($root, $source->{$name}, $name); 		
	}
}


#Transform complex name into a HASH.
#$root - root reference
#$val - complex name value 
#$complex_name - complex name which will be transformed to HASH
#EXAMPLE: WEBSITE.VIEW.IMAGE will be transformed to {'WEBSITE'}{'VIEW'}{'IMAGE'}
#return: void
#------------------------------------------------------------------------------
sub updateComplexParameter {
    my ($root, $val, $complex_name) = @_;
    _make_value($root, $val, split(/\./, $complex_name));
}



#Gets value using not {'WEBSITE'}{'VIEW'}{'IMAGE'} but "WEBSITE.VIEW.IMAGE" notation
#$data "HASH REF" - data value will be seeking
#$name "SCALAR" (string likes WEBSITE.VIEW.IMAGE) - complex name
#Returns: seeking value or undef
#------------------------------------------------------------------------------
sub getValueByComplexName {
	my ($data, $name) = @_;
	return $data->{$name} if not DCP::Name2HashTransformer::isComplexName($name);
	return _get_value($data, split(/\./, $name));
}


#------------------------------------------------------------------------------
sub _get_value {
    my ($data, @complex_name) = @_;

    my $param = shift @complex_name;

    if (not $param) {
    	return $data;
    }
    return _get_value($data->{$param}, @complex_name);
}

#------------------------------------------------------------------------------
sub _make_value {
    my ($root, $val, @complex_name) = @_;

    my $param = shift @complex_name;
    $root->{$param} ||= {};

    if (scalar @complex_name) {
        _make_value($root->{$param}, $val, @complex_name);
    }
    else {
        $root->{$param} = $val;
    }
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
1;

