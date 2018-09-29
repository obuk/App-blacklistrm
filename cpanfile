# -*- mode: cperl -*-

requires 'perl', '5.010001';

requires 'common::sense';
#requires 'DateTime';
requires 'DB_File';
requires 'Fcntl';
requires 'Moo';
requires 'MooX::Options';
requires 'Perl6::Slurp';
requires 'Socket', '2.027';

on 'test' => sub {
  requires 'Test::More', '0.98';
};
