load_extension('Dist::Build::XS');

create_node(
	target => 'lib/File/StatX.xs',
	dependencies => [ 'lib/File/StatX.xs.PL' ],
	actions => [
		command(perl_path(), 'lib/File/StatX.xs.PL', 'lib/File/StatX.xs'),

	]
);

auto_xs();
