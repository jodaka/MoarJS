package Parse::CSS;

use strict;
use warnings;
use File::Basename;
use File::Stat;
use CSS::Minifier::XS qw/minify/;
use utf8;
use Data::Printer;

sub new {
    bless {},
    shift;
}

# here cache lives
my %cache;
my $recursion_level = 0;
my %params;

# Cleaning stale cache items
sub cache_cleanup {
    my $self = shift;
    my $cleanup_timeout = shift;
    my $now = time();

    for my $file (keys %cache) {
        if ($now - $cache{$file}{'last_access_time'} > $cleanup_timeout) {
            delete $cache{$file};
        }
    }
}

# Main CSS file processing routine.
# Will parse file and store it in cache.
# On every next run cache is being checked. If nodes in cache doesn't changed on disk,
# no parsing is being done.
#
sub process {

    my $self        = shift;
    my $node        = shift;
    my $params      = shift;

    %params = %{$params};

    # recursively check node's timestamp and rebuild if needed
    local *recursive_check = sub {

        my $leaf = shift;
        my $mtime = (stat $leaf)[9];

        # checking node timestamp
        if (!$cache{$leaf} || $cache{$leaf}{'timestamp'} != $mtime) {
            return 0;
        }

        for my $dep (@{$cache{$leaf}{'deps'}}) {

            if (!recursive_check($dep)) {
                delete $cache{$dep};        # dep node reset
                $self->parse($dep, dirname($leaf));         # rebuilding dep

                delete $cache{$leaf};       # current node reset
                $self->parse($leaf);        # rebuilding node

            };
        }

        return 1;

    };

    # first, check filename
    # what starts with _ (underscore) would be just concatenated
    my $_filename = my $_realname = basename($node);
    $_realname =~ s/^_//;
    my $_dir      = dirname($node);

    my $need_compressing = $params{'compress'} && $_filename !~ m/^_/;

    if (-e $_dir."/".$_realname) {

        # real path is real :)
        $node = $_dir."/".$_realname;

        # check if node was modified
        if (!recursive_check($node)) {
            $self->parse($node);
        };

        # do we need to compress?
        if ($need_compressing && !exists $cache{$node}{'compressed'}) {
            $cache{$node}{'compressed'} = minify($cache{$node}{'content'});
        }

        $cache{$node}{'last_access_time'} = time();

        return ($need_compressing)
            ? $cache{$node}{'compressed'}
            : $cache{$node}{'content'};
    }

    return '';
}

# recursively searching for include("") construction in JS files
#
sub parse {

    my ($self, $file) = @_;
    my $res = '';

    # do we already have cached version?
    if (exists $cache{$file}) {
        $cache{$file}{'last_access_time'} = time();
        return $cache{$file}{'content'};

    } else {

        # no cache, or cache is outdated
        $cache{$file} = {
            'timestamp'        => '',
            'content'          => '',
            'deps'             => [],
            'last_access_time' => 0,
        };

        # reading file
        if (open(my $css, "<:encoding(UTF-8)", $file)) {

            my $dir = dirname($file);
            while (<$css>) {
                my $str = $_;

                if ($str =~ m/\s*\@import (?:url\()?(?:'|")?(.*?)(?:'|")?\)?;/) {

                    my $inline_css = $dir."/$1";

                    # Storing dependencies for file
                    push @{$cache{$file}{'deps'}}, $inline_css;

                    if ($params{'debug'}) {

                        $res .= "    " x $recursion_level . qq~/* ↪ $inline_css */\n~;
                    }

                    $recursion_level++;

                    $res .= $self->parse($inline_css);

                    if ($params{'debug'}) {
                        $res .= "    " x $recursion_level . qq~/* ↩ $inline_css */\n\n\n~;
                    }

                    $recursion_level--;

                } else {
                    # nothing interesting, just some CSS rules
                    $res .= ($params{'debug'})
                        ? "    " x ($recursion_level+1) . $str
                        : $str;
                }
            }

            close($css);
            # stroring last access time
            $cache{$file}{'last_access_time'} = time();
            # storing last modified timestamp
            $cache{$file}{'timestamp'} = (stat $file)[9];
            # and file contents
            $cache{$file}{'content'}   = $res;

        } else {
            # TODO FIXME here should be some die statement
            warn("\n\n\n Error can't open $file $!\n");
        }

        return $res;
    }
}


1;
