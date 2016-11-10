#!/usr/bin/perl

use strict;
use DCP::Log;

use FastTemplateEngine;

my @examples = (
    "e001.html",
    "e002.html",
    "e003.html",
    "e004_loop.html",
    "e006.html",
    "e007.html",
    "e008_change.html",
    "e009_formatter.html",
    "e010_with.html",
    "e011_array.html",
    "e012_set.html",
    "e013_import.html"
);


$::localized_msgs = {
    "hello" => "привет",
    "tref_example" => "example of text ref ",
    "expand_example" => "example of text expand {% test %}"
};

my $data = {
    "aaa"   => "BBBB",
    "test"  => "UUUUUUU",
    "xhtml" => "<td></td>",
    "tref"  =>  "tref_example",
    "bobick" => [1,2],
    "mummik" => 1115,
    "ARR" => ["A", "B", "C", "D"],
    "ARRB" => [["A", "B"], ["C", "D"]],
    'DOT' => {
            'DA' => {
                      "LL" =>[{"AAA"=>1}, {"BBB"=>2}, {"CCC"=>3}],
                      "XX" =>[1, 2, 3, 4, 5, 6, 7],
                      'DB' => {
                                'DC' => {
                                          'DD' => '### dpxtkt ###'
                                        }
                              }
                    }
    },


    "list_test" => [
        {"name" => 1111, "value" => 114, "inner"=>[
            {"VVX" => 100},
            {"VVX" => 101},
            {"VVX" => 102},
        ]},
        {"name" => 1112, "value" => "5555", "inner"=>[
            {"VVX" => 100},
            {"VVX" => 101},
            {"VVX" => 102},
        ]},
        {"name" => 1112, "value" => "" },
        {"name" => 1113, "value" => 0 },
        {"name" => 1113, "value" => 8 },
        {"name" => 2, "value" => 000},
        {"name" => 2, "value" => []},
        {"name" => 3, "value" => {}},
    ],
    "dottest" => {"value" => 777}
};

sub external_test_method_001 {
    use integer;
    my ($name, $value) = @_;
    print "PARAM: [$name][$value]\n";
    return $value && $name % 2 && $name > 1000;
}


sub formatter_001 {
    my ($param) = @_;
    return "<<FORMATTED PARAM: '$param'>>";
}

addTemplateFolders("./examples");
for my $template_filename (@examples) {
    eval {
        my $page = render_template($template_filename, $data, 0);
        print $page;
    };
    print $@;
}



