#!/usr/bin/env perl

use strict;
use warnings;

use Convert::IBM390 qw(:all);
use Getopt::Long;
use Pod::Usage;

my ($ebcdic, $ascii, $file, $newline, $debug, %cols, $record_len, $record_fmt);
my ($rec, $buf, $separator, $codepage) = (0, "", "\t", "CP01141");

my %types = (
	p => { type => "p", length => sub { return int(($_[0]+1)/2.0+0.5); } }, P => { type => "P", length => sub { return int(($_[0]+1)/2.0+0.5); } },
	e => { type => "e", length => sub { $_[0]; } }, E => { type => "E", length => sub { $_[0]; } },
	c => { type => "c", length => sub { $_[0]; } }, C => { type => "C", length => sub { $_[0]; } },
	z => { type => "z", length => sub { $_[0]; } }, Z => { type => "Z", length => sub { $_[0]; } },
	s => { type => "s", length => 2              }, S => { type => "S", length => 2              },
	i => { type => "i", length => 4              }, I => { type => "I", length => 4              },
);

GetOptions (
			"ebcdic"		=> sub { $ebcdic = 1; $ascii = 0 },
			"ascii"			=> sub { $ascii = 1; $ebcdic = 0 },
			"newline|n"		=> \$newline,
			"separator|s=s"	=> \$separator,
			"debug|d"		=> \$debug,
			"file=s"		=> \$file,
			"codepage=s"	=> \$codepage,
			"c=i"			=> sub {my ($opt, $col) = @_;
									die "missing record specification after -c $col"  unless $ARGV[0];
									if ($ARGV[0] =~ /(?<type>\w)\[(?<scale>\d+)[,]?(?<prec>\d+)?\]/) {
										die "unknown type $+{type} after -c $col" unless $types{$+{type}};
										$cols{$col}{len} = &{$types{$+{type}}{length}}($+{scale}, $+{prec});
										$cols{$col}{fmt} = $types{$+{type}}{type}.$cols{$col}{len};
										$cols{$col}{fmt} .= ".$+{prec}" if (defined $+{prec});
									} elsif ($ARGV[0] =~ /(?<type>\w)/) {
										die "unknown type $+{type} after -c $col" unless $types{$+{type}};
										$cols{$col}{len} = $types{$+{type}}{length};
										$cols{$col}{fmt} = $types{$+{type}}{type};
									}},
			"help|?"		=> sub { pod2usage(1); exit(0); },
			"man"			=> sub { pod2usage(-verbose => 2); exit(0); }, ) or pod2usage(1);

die "must specify conversion - either -a(scii) or -e(bcdic)" unless $ebcdic or $ascii;
die "must specify input file" unless $file;

set_codepage($codepage);

my @cols = sort { $a <=> $b } keys %cols;
$record_len += $cols{$_}{len} foreach (@cols);
print STDERR "record length: $record_len bytes\n";
$record_fmt .= $cols{$_}{fmt}." " foreach (@cols);

open(my $fh, "<", $file) or die $!;

if ($ascii) {	# EBCDIC => ASCII
	binmode $fh;
	no warnings 'uninitialized';
	while (!eof($fh)) {
		read $fh, $buf, $record_len or die $!;
		read $fh, $buf, 1 if $newline;
		print STDERR "REC: $rec\n", hexdump($buf), "\n" if $debug;
		print join($separator, unpackeb $record_fmt, $buf), "\n";
		$rec++;
	}
} else {	# ASCII => EBCDIC
	binmode STDOUT;
	no warnings 'numeric';
	while (<$fh>) {
		chomp;
		my $data = packeb $record_fmt, split($separator, $_, -1);
		print STDERR "REC: $rec\n", hexdump($data), "\n" if $debug;
		print $data;
		print "\n" if $newline;
		$rec++;
	}
}
close($fh);

print STDERR "converted $rec records\n";

1;

__END__

=head1 NAME

conv.pl - Convert ebcdic file into ascii (and vice-versa).

=head1 SYNOPSIS

perl conv.pl [options]

=head1 OPTIONS

=over 8

=item B<--ascii|-a>

Convert from EBCDIC to ASCII.

=item B<--ebcdic|-e>

Convert from ASCII to EBCDIC.

=item B<--codepage CODEPAGE>

Specifies the EBCDIC codepage to use for conversion. See Convert::IBM390 for all available codepages (default=CP01141 (Germany (EURO)).

=item B<-c COL CONV>

Specifies the conversion CONV to be applied to column COL.
Currently supported conversion are: cC eE pP zZ sS iI (see Convert::IBM390 packeb/unpackeb).

=item B<--debug|-d>

Print some debug output to STDERR (default=OFF).

=item B<--newline|-n>

Read/write newline as a record (i.e. line) separator (default=NONE).

=item B<--separator|-s SEPARATOR>

Use SEPARATOR as column separator (default=TAB (\t)).

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=head1 SEE ALSO

L<Convert::IBM390>

=head1 EXAMPLE

Let's say one has a TAB separated file test.dat with the following contents:

 2015    2       32      65938812        2012-08-03      -476.55
 2015    2       32      544241370       2012-11-13      -215.12
 2015    2       32      64629999        2012-04-20      -1945.45
 2015    2       32      504723399       2012-10-31      0.14
 2015    2       98      70444151        2012-03-16      -139.8
 2015    2       32      516943793       2012-01-01      0.02
 2015    2       30      70775638        2012-11-08      -642.7
 2015    2       32      62962003        2012-11-04      -29.31
 2015    2       30      387784276       2011-12-23      0.63
 2015    2       30      67197232        2012-10-30      -56.25

To convert that file to EBCDIC, one would call conv.pl like this:

./conv.pl -f test.dat -e -c 0 e[4] -c 1 z[2,0] -c 2 e[2] -c 3 p[9,0] -c 4 e[10] -c 5 p[12,2] > test.ebcdic

To convert the EBCDIC file back to ASCII, one would call conv.pl like this:

./conv.pl -f test.ebcdic -a -c 0 e[4] -c 1 z[2,0] -c 2 e[2] -c 3 p[9,0] -c 4 e[10] -c 5 p[12,2] > test.ascii

=head1 AUTHOR

Sinisa Susnjar <sini@cpan.org>

=cut
