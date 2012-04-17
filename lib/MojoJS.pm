package MojoJS;

use Mojo::Base 'Mojolicious';
use utf8;

use ParseJS;
use ETag;

## Настройки
use constant ROOT_URI  => '/';
use constant ROOT_PATH => '/Users/jodaka/git/tv'; # TODO FIXME remove this
use constant DEBUG     => 1; # 1/0
use constant COMPRESS  => 0;

sub startup {

    my $self = shift;

    my %parsers;
    # Parsers
    $parsers{'js'} = ParseJS->new;

    # Helper function returning our model object
    $self->helper(
        js => sub {
            return $parsers{'js'}
        }
    );

    #plugin for ETag header
    ETag->register($self);

    # Make signed cookies secure
    $self->secret('MojoJS');


    # registering new types
    # for JS and CSS
    $self->types->type(
        JS  => 'application/javascript; charset=utf-8',
        CSS => 'text/css; charset=utf-8'
    );

    # configure routing
    my $r = $self->routes;

    # handling of JS files

    $r->get('/(:js*.js)' => sub {

        my $self = shift;

        # Query parameters
        my $requestPath = ROOT_PATH.'/'.$self->param('js').'.js' || '';

        my $res = $self->js->process($requestPath, COMPRESS);

        #my $res = (COMPRESS) ? Closure->compress($concat) : $concat;

        return $self->render(
            text   => $res,
            format => 'JS'
        );
    });

    # TODO FIXME check this and remove
    $r->any('/' => sub {
        my $self = shift;
        return $self->render(txt => 'halo');
    });
};

1;
