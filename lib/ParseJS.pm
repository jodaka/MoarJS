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

my %cache;


sub process {

    my $self = shift;
    my $node = shift;
    my $compress = shift;

    my $deep = 0;

    local *recursive_check = sub {
        my $leaf = shift;

        $deep++;

        my $mtime = (stat $leaf)[9];

        # если поменялось время доступа, значит поменялась нода
        if (!$cache{$leaf} || $cache{$leaf}{'timestamp'} != $mtime) {
            return 0;
            #warn (Dumper(\%cache));
        }

        # if (!$cache{$leaf} || !$cache{$leaf}{'deps'}) {
        #     $self->parse($leaf, $compress);
        # }

        for my $dep (@{$cache{$leaf}{'deps'}}) {
            warn("deps scan $dep");

            if (!recursive_check($dep)) {
                warn('scan fail');
                delete $cache{$dep}; # обнуляем зависимость
                $self->parse($dep, $compress);  # перестраиваем зависимость

                delete $cache{$leaf}; # обнуляем родителя
                $self->parse($leaf, $compress); # перестраиваем родителя

                recursive_check($leaf);
            };
        }

        $deep--;
    };

    warn(basename($node));
    my $_filename = my $_realname = basename($node);
    $_realname =~ s/^_//;
    my $_dir      = dirname($node);

    if ($_filename =~ /^_/ && -e $_dir."/".$_realname) {

        $node = $_dir."/".$_realname;

        if (!recursive_check($node)) {
            warn('initial scan');
            $self->parse($node, $compress);
        };

        if ($compress && !exists $cache{$node}{'compressed'}) {
            warn(" ~~ COMPRESSING ");
            $cache{$node}{'compressed'} = Closure->compress($cache{$node}{'content'});
        }

        return ($compress)
            ? $cache{$node}{'compressed'}
            : $cache{$node}{'content'};
    }

    return '';


}

# парсим JS файл на предмет наличия в нём
# конструкций include()
sub parse {

    my ($self, $file, $compress) = @_;
    my $res = '';

    if (exists $cache{$file}) {
        return $cache{$file}{'content'};

    } else {

        # no cache, or outdated
        $cache{$file} = {
            'timestamp'  => '',
            'content'    => '',
            'deps'       => [],
        };

        warn ("--> rebuilding $file");

        # reading file
        if (open(my $js, "<:encoding(UTF-8)", $file)) {

            my $dir = dirname($file);

            while (<$js>) {
                if (m/\s*include\("(.*?)"\);/) {
                    # Storing dependencies for file
                    my $inlinejs = $dir."/$1";
                    push @{$cache{$file}{'deps'}}, $inlinejs;
                    $res .= $self->parse($inlinejs);
                } else {
                    $res .= $_;
                }
            }
            close($js);
            $cache{$file}{'timestamp'} = (stat $file)[9];
            $cache{$file}{'content'} = $res;

        } else {
            warn(" ~~~ can't open $file \n");
        }

        return $res;
    }
}



1;
