#!/bin/perl

use strict;
use warnings;
use JSON qw( decode_json );
use Data::Dumper;

my $json_string = '{"success":true,"age":347,"data":{"version":"B","tme":"0208201329","rbc":"38","rbt":"1098572148","car":"1","amp":"10","err":"0","ast":"0","alw":"1","stp":"0","cbl":"0","pha":"56","tmp":"35","tma":[29.75,29.63,29.5,29.63],"amt":"32","dws":"0","dwo":"0","adi":"0","uby":"0","eto":"5940","wst":"3","txi":"1","nrg":[227,230,229,1,0,0,0,0,0,0,0,0,0,0,0,0],"fwv":"033","sse":"012345","wss":"GastWLAN","wke":"","wen":"1","cdi":"0","tof":"101","tds":"1","lbr":"33","aho":"3","afi":"7","azo":"0","ama":"32","al1":"9","al2":"10","al3":"16","al4":"20","al5":"0","cid":"255","cch":"65535","cfi":"65280","lse":"0","ust":"0","wak":"","r1x":"0","dto":"0","nmo":"0","sch":"AAAAAAAAAAAAAAAA","sdp":"0","eca":"0","ecr":"0","ecd":"0","ec4":"0","ec5":"0","ec6":"0","ec7":"0","ec8":"0","ec9":"0","ec1":"0","rca":"2922","rcr":"","rcd":"","rc4":"","rc5":"","rc6":"","rc7":"","rc8":"","rc9":"","rc1":"","rna":"","rnm":"","rne":"","rn4":"","rn5":"","rn6":"","rn7":"","rn8":"","rn9":"","rn1":"","loe":0,"lot":0,"lom":0,"lop":0,"log":"","lon":0,"lof":0,"loa":0,"lch":0,"upd":"0"}}';

my $json_data = decode_json( $json_string );

print Dumper $json_data;

print keys %{ $json_data->{'data'} };

my @vtmp = @{ $json_data->{'data'}{'tma'} };
my $value = join " ", @vtmp;

print "\n<< $value >>\n";
