#!/usr/bin/env perl

use strict;
use warnings;
use lib "lib";
use utf8;

use File::Basename 'dirname';
use File::Spec::Functions qw/catdir splitdir/;

# Source directory has precedence
my @base = (splitdir(dirname(__FILE__)), '..');
my $lib = join('/', @base, 'lib');
-e catdir(@base, 't') ? unshift(@INC, $lib) : push(@INC, $lib);

# Check if Mojolicious is installed
die <<EOF unless eval 'use Mojolicious::Commands; 1';
It looks like you don't have the Mojolicious framework installed.
Please visit http://mojolicio.us for detailed installation instructions.

EOF

# Start commands for application
Mojolicious::Commands->start_app('MojoJS');


# get '/(:css*.css)' => sub {
#     my $self = shift;
#     $self->render(text => process_css($self->param('css')));

# };