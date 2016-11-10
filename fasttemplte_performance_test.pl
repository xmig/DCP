#!/usr/bin/perl

use strict;
use DCP::Log;

use FastTemplateEngine;


my $template_name = "test_001.txt";


my ($code_name) = ($template_name =~ /(.*?)\.html$/);
$code_name = "./DCPWX/" . $code_name . "_code.pm";


$::localized_msgs = {
    "hello" => "привет",
    "tref_example" => "example of text ref ",
    "expand_example" => "example of text expand {% test %}"
};

sub leading_zeros {
    my($num, $zeros) = @_;
    $zeros ||= 6;
    my $s = "$num";
    while(length($s) < $zeros) {
        $s = '0' . $s;
    }
    return $s;
}

sub next_n1 {
    $::n1++;
    return leading_zeros($::n1);
}

sub next_n2 {
    $::n2++;
    return leading_zeros($::n2);
}


sub random_str {
    my ($chars_count) = @_;
    $chars_count ||= 10;
    return join("", map { (q(a)..q(z))[rand(26)] } 1..$chars_count);
}


%::data = ();

my $data = {
    "mode"   => "*** TEST ***",

    "PERFORM" => {
        "LIST" => [
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20), 'SUB'=>[
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                {"XXX"=>"subline" . next_n2(), "value" => "*** " . random_str(4) . " ***"},
                ]},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20), "DOT"=>[
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}},
                {"DA" => {"DB" => {"DC" => {"DD" => "### " . random_str(6) . " ###"}}}}


                ]},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
            {"NAME"=>"line" . next_n1(), "time" => time, "value" => random_str(20)},
        ]
    }
};

addRowNumber($data->{'PERFORM'}{"LIST"});
logDump($data);

#print random_str();
#print leading_zeros(21);
#exit;

addTemplateFolders("./templates");
for (my $i=0; $i < 10000; $i++) {
    eval {
        #$::page = render($template_name, "STRING:[{% aaa %}]\n.", "memory");
        $::page = render_template($template_name, $data, 1);
    };
    print $@;
}

print $::page;
#logDump($data)

