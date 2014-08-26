use strict;
use warnings;
use inc::Module::Install;
use 5.008005;

name 'AWS-S3';
perl_version '5.008001';
license 'perl';
all_from 'lib/AWS/S3.pm';

test_requires 'Test::More'  => '0';

requires 'Moose'                         => '2.0';
requires 'MooseX::Types';
requires 'MooseX::Types::URI';
requires 'Class::Load';
requires 'XML::LibXML';
requires 'XML::LibXML::XPathContext';
requires 'LWP::UserAgent::Determined';
requires 'Carp';
requires 'HTTP::Date';
requires 'MIME::Base64';
requires 'URI::Escape';
requires 'Digest::HMAC_SHA1';
requires 'Iterator::Paged';
requires 'Test::Deep';

resources(
  'repository'  => 'https://github.com/jdrago999/AWS-S3'
);


tests_recursive();
WriteAll();

