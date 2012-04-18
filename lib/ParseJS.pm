package ParseJS;

use strict;
use warnings;
use File::Basename;
use File::Stat;
use utf8;
use Closure;

use Data::Dumper qw/Dumper/;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Deparse = 1;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys = 1;

sub new {
    bless {},
    shift;
}


# here cache lives
my %cache;


# Main JS file processing routine.
# Will parse file and store it in cache.
# On every next run cache is being checked. If nodes in cache doesn't changed on disk,
# no parsing is being done.
#
sub process {

    my $self     = shift;
    my $node     = shift;
    my $compress = shift;

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
                $self->parse($dep);         # rebuilding dep

                delete $cache{$leaf};       # current node reset
                $self->parse($leaf);        # rebuilding node

                #recursive_check($leaf);
            };
        }

        return 1;

    };

    # first, check filename
    # what starts with _ (underscore) would be just concatenated
    my $_filename = my $_realname = basename($node);
    $_realname =~ s/^_//;
    my $_dir      = dirname($node);

    my $need_compressing = $compress && $_filename !~ m/^_/;

    if (-e $_dir."/".$_realname) {

        # real path is real :)
        $node = $_dir."/".$_realname;

        # check if node was modified
        if (!recursive_check($node)) {
            $self->parse($node);
        };

        # do we need to compress?
        if ($need_compressing && !exists $cache{$node}{'compressed'}) {
            $cache{$node}{'compressed'} = Closure->compress($cache{$node}{'content'});
        }

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

        return $cache{$file}{'content'};

    } else {

        # no cache, or cache is outdated
        $cache{$file} = {
            'timestamp'  => '',
            'content'    => '',
            'deps'       => [],
        };

        # reading file
        if (open(my $js, "<:encoding(UTF-8)", $file)) {

            my $dir = dirname($file);
            while (<$js>) {

                if (m/\s*include\("(.*?)"\);/) {

                    my $inlinejs = $dir."/$1";
                    # Storing dependencies for file
                    push @{$cache{$file}{'deps'}}, $inlinejs;
                    # recursively parse file
                    $res .= $self->parse($inlinejs);
                } else {
                    # nothing interesting, just some JS sources
                    $res .= $_;
                }
            }
            close($js);

            # storing last modified timestamp
            $cache{$file}{'timestamp'} = (stat $file)[9];
            # and file contents
            $cache{$file}{'content'}   = $res;

        } else {
            # TODO FIXME here should be some die statement
            warn(" ~~~ can't open $file \n");
        }

        return $res;
    }
}


1;
