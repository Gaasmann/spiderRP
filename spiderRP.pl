#!/usr/bin/env perl

use strict;
use warnings;
use diagnostics;

use LWP;
use URI;
use Email::Stuffer;
use Data::Dumper;
use HTML::TreeBuilder;

my $browser = LWP::UserAgent->new;
$browser->cookie_jar( {} );
my $url = URI->new("https://services3.cic.gc.ca/ecas/authenticate.do");

push @{$browser->requests_redirectable}, 'POST';

my $cic_code = "01234567";
my $surname = "Macron";
my $birthdate = "1977-12-21";
my $country = "022";

my @dest = (
    'president@elysee.fr',
    'manu@wanadoo.fr'
);

my $response = $browser->post($url,
    [
	lang => "",
	_page => "_target0",
	app => "",
	identifierType => "1",
	identifier => $cic_code,
	surname => $surname,
	dateOfBirth => $birthdate,
	countryOfBirth => $country,
	_submit => "Continuer"
    ]
);

$response->is_success || die "POST failed: $response->status_line";
my $generalTree = HTML::TreeBuilder->new;
$generalTree->parse($response->content);
my $tbody = $generalTree->look_down(_tag => 'tbody');
my @trs = $tbody->look_down(_tag => 'tr',
                           class => "align-center");
# save URL base of general page
my $base = $response->base;
my $info_to_print;
foreach my $tr (@trs) {
    $info_to_print .=  "-------------------------\n";
    my @tds = $tr->look_down(_tag => 'td');
    $info_to_print .=  shift(@tds)->format; # Print the name of the person
    my @info;
    foreach my $td (@tds) {
	$info_to_print .=  "---------\n";
	my $general_status = $td->format;
	$general_status =~ s/(^\s+|\s$)//g;
	$info_to_print .=  "\tGeneral status: " . $td->format . "\n";
	my $a = $td->look_down(_tag => 'a');
	my $rel_url = $a->attr('href');
	# Construct URL for detailed info and get the page
	$response = $browser->get(URI->new_abs($rel_url,$base));
	$response->is_success || die "GET failed: $response->status_line";
	# Parse the page to get the second ordered list
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($response->content);
	my @node = $tree->look_down(_tag => 'ol');
	my $detailed_status =  $node[1]->format;
	$info_to_print .=  $detailed_status;
    }
}
# Send an email
my $email = Email::Stuffer->new;
$email->to('Osef 12000<blah@exemple.com>')
      ->from('Spider RP<spiderrp@boiteameuh.org>')
      ->subject('RP status! RP Status!');
my $body = <<BODY
Hello!

Here the status of your application(s):
$info_to_print

Enjoy! (or not)

-- 
Spider RP
BODY
;

$email->text_body($body);
foreach my $address (@dest) {
    $email->to($address);
    $email->send;
}
