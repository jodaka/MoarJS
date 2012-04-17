package Closure;

use strict;
use warnings;
use utf8;
use IPC::Run3;


sub compress {
	my ($self, $data) = @_;

	my ($out, $err);

	run3(['closure'], \$data, \$out, \$err);
	return $out;
}


1;