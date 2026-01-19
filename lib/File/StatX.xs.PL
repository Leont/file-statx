my $output_name = shift;

open my $fh, '>', $output_name;

print $fh <<'END';

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

typedef struct statx* File__StatX;

#define STATX_TYPEMODE (STATX_TYPE | STATX_MODE)

MODULE = File::StatX				PACKAGE = File::StatX

TYPEMAP: <<TYPEMAP
	File::StatX T_OPAQUEOBJ
TYPEMAP

BOOT:
	HV* stash = gv_stashpvs("File::StatX", GV_ADD | GV_ADDMULTI);
END

my @constants = qw/MODE NLINK UID GID ATIME MTIME CTIME INO SIZE BLOCKS BASIC_STATS BTIME ALL/;

for my $constant (@constants) {
	printf $fh qq/\tnewCONSTSUB(stash, "STATX_$constant", newSVuv(STATX_$constant));\n/;
}

my @constants_maybe = qw/MNT_ID DIOALIGN MNT_ID_UNIQUE SUBVOL WRITE_ATOMIC DIO_READ_ALIGN/;

for my $constant (@constants_maybe) {
	printf $fh <<"END";
#ifdef STATX_$constant
	newCONSTSUB(stash, "STATX_$constant", newSVuv(STATX_$constant));
#endif
END
}

print $fh <<'END';


File::StatX new(class)
CODE:
	RETVAL = safecalloc(1, sizeof(struct statx));
OUTPUT:
	RETVAL

SV* mask(File::StatX self)
CODE:
	RETVAL = newSVuv(self->stx_mask);
OUTPUT:
	RETVAL


END

my %uv_methods = (
	blksize    => 'BLOCKS',
	nlink      => 'NLINK',
	uid        => 'UID',
	gid        => 'GID',
	mode       => 'TYPEMODE',
	ino        => 'INO',
	size       => 'SIZE',
	blocks     => 'BLOCKS',
	dev_major  => 'BASIC_STATS',
	dev_minor  => 'BASIC_STATS',
	rdev_major => 'BASIC_STATS',
	rdev_minor => 'BASIC_STATS',
);
for my $key (sort keys %uv_methods) {
	print $fh <<"END";
SV* $key(File::StatX self)
CODE:
	if (self->stx_mask & STATX_$uv_methods{$key})
		RETVAL = newSVuv(self->stx_$key);
	else
		RETVAL = &PL_sv_undef;
OUTPUT:
	RETVAL

END
}

my %time_methods = (
	atime => 'ATIME',
	btime => 'BTIME',
	ctime => 'CTIME',
	mtime => 'MTIME',
);
for my $key (sort keys %time_methods) {
	print $fh <<"END";
SV* $key(File::StatX self)
CODE:
	if (self->stx_mask & STATX_$time_methods{$key})
		RETVAL = newSVnv(self->stx_$key.tv_sec + (self->stx_$key.tv_nsec / 1000000000.0));
	else
		RETVAL = &PL_sv_undef;
OUTPUT:
	RETVAL

END
}

my %maybe_methods = (
	mnt_id                    => 'MNT_ID',
	subvol                    => 'SUBVOL',
	atomic_write_unit_min     => 'WRITE_ATOMIC',
	atomic_write_unit_max     => 'WRITE_ATOMIC',
	atomic_write_segments_max => 'WRITE_ATOMIC',
	atomic_write_unit_max_opt => 'WRITE_ATOMIC',
	dio_mem_align             => 'DIO_ALIGN',
	dio_offset_align          => 'DIO_ALIGN',
	dio_read_offset_align     => 'DIO_READ_ALIGN',
);
for my $key (sort keys %maybe_methods) {
	print $fh <<"END";
SV* $key(File::StatX self)
CODE:
#ifdef STATX_$maybe_methods{$key}
	if (self->stx_mask & STATX_$maybe_methods{$key})
		RETVAL = newSVuv(self->stx_$key);
	else
#endif
		RETVAL = &PL_sv_undef;
OUTPUT:
	RETVAL

END
}

my @attributes = qw/compressed immutable append nodump encrypted verity write_atomic dax mount_root/;
for my $key (sort @attributes) {
	print $fh <<"END";
SV* $key(File::StatX self)
CODE:
#ifdef STATX_\U$key\E
	if (self->stx_attributes_mask & STATX_ATTR_\U$key\E)
		RETVAL = newSVbool(self->stx_attributes & STATX_ATTR_\U$key\E);
	else
#endif
		RETVAL = &PL_sv_undef;
OUTPUT:
	RETVAL

END

}
