use inc::Module::Install;
name 'Sledge-HTTPSession';
all_from 'lib/Sledge/HTTPSession.pm';

requires 'Moose' => 0.59;
requires 'HTTP::Session' => 0.21;
requires 'CGI';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
test_requires 'Class::Trigger';
test_requires 'Test::More';
test_requires 'YAML';
author_tests 'xt';
use_test_base;
auto_include;
WriteAll;