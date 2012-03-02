use strict;
use warnings;
use inc::Module::Install;
use 5.008005;

name 'AWS-S3';
perl_version '5.008001';
license 'perl';
all_from 'lib/AWS/S3.pm';

test_requires 'Test::More'  => '0';

requires      'VSO'                         => '0.024';
requires      'Class::Load'                 => '0';
requires      'XML::LibXML'                 => '0';
requires      'XML::LibXML::XPathContext'   => '0';
requires      'LWP::UserAgent::Determined'  => '0';
requires      'Carp'                        => '0';
requires      'HTTP::Date'                  => '0';
requires      'MIME::Base64'                => '0';
requires      'URI::Escape'                 => '0';
requires      'URI::QueryParam'             => '0';
requires      'URI::Escape'                 => '0';
requires      'Digest::HMAC_SHA1'           => '0';
requires      'Iterator::Paged'             => '0';

resources(
  'repository'  => 'https://github.com/jdrago999/AWS-S3'
);


tests_recursive();
WriteAll();

