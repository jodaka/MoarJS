package MojoJS;

use Mojo::Base 'Mojolicious';
use utf8;
use Cwd qw/getcwd/;
use JSON qw/from_json/;

use Parse::CSS;
use Parse::JS;
use ETag;

my %sites;

# TODO FIXME (better error handling)
# trying to read and parse
sub read_config {
    my $self = shift;

    my $current_dir = getcwd();

    if (-e "$current_dir/moarjs.config") {


        if (open(my $cfg, "<:encoding(UTF-8)", "$current_dir/moarjs.config")) {
            my $config = '';
            while(<$cfg>) {
                $config .= $_;
            }
            close($cfg);

            eval {
                %sites = %{from_json($config)};
            };

            if ($@) {
                die("Bad config format: $@");
            }
        } else {
            # no rights to read config
            die("Can't read moarjs.config in the $current_dir: $!");
        }
    } else {
        # no config file found
        die("Can't find moarjs.config in the $current_dir");
    }

    return 1;
    # if (-e moarjs.config)
}

# main routine
sub startup {

    my $self = shift;

    # reading config file
    $self->read_config();

    # Parsers
    my %parsers;
    $parsers{'js'}  = Parse::JS->new;
    $parsers{'css'} = Parse::CSS->new;

    #plugin for ETag header
    ETag->register($self);

    # Make signed cookies secure
    $self->secret('MoarJS');

    # registering new types
    # for JS and CSS
    $self->types->type(
        js  => 'application/javascript; charset=utf-8',
        css => 'text/css; charset=utf-8'
    );

    # configure routing
    my $r = $self->routes;

    # TODO FIXME check this and remove
    $r->get('/(:url*)'  => sub {

        my $self = shift;
        my $url  = $self->param('url');

        my $hostname  = $self->req->url->base->host;
        my @path      = @{$self->req->url->path->parts};
        my $extension = '';

        # last part is filename, so we check extension
        unless ($path[$#path] =~ /\.(js|css)$/) {
            return $self->render(text => "$url isn't JS or CSS");
        } else {
            $extension = lc($1);
        }

        # check hostname against all configured urls
        for my $regex_url (keys %sites) {

            if ($hostname =~ /$regex_url/) {

                my $request_path = $sites{$regex_url}{'root_path'} . $self->req->url->path->to_string;

                my $res = $parsers{$extension}->process($request_path, $sites{$regex_url});

                return $self->render(
                    text   => $res,
                    format => $extension
                );

            }

        }

        return $self->render(text => "Cant't find any proper configuration for handling $url");
    });
};

1;
