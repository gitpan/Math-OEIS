# Copyright 2010, 2011, 2012, 2013, 2014 Kevin Ryde

# This file is part of Math-OEIS.
#
# Math-OEIS is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# Math-OEIS is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Math-OEIS.  If not, see <http://www.gnu.org/licenses/>.

package Math::OEIS::Stripped;
use 5.006;
use strict;
use Carp 'croak';

use Math::OEIS::SortedFile;
our @ISA = ('Math::OEIS::SortedFile');

our $VERSION = 3;

use constant base_filename => 'stripped';

# Maximum number of decimal digits which fit within a Perl UV integer.
# For example a 32-bit UV goes up to 2^32-1 = 4294967295 and in that case
# UV_DECIMAL_DIGITS_MAX is 9 since values up to and including 9 digits
# fit into a UV.  Some 10 digit values fit too, but not all 10 digits.
#
use constant UV_DECIMAL_DIGITS_MAX => length(~0)-1;

sub new {
  my $class = shift;
  return $class->SUPER::new (use_bigint => 'if_necessary',
                             @_);
}

sub anum_to_values_str {
  my ($self, $anum) = @_;
  ### anum_to_values_str(): $anum

  my $line = $self->anum_to_line($anum);
  if (! defined $line) { return undef; }

  my ($got_anum, $values_str) = $self->line_split_anum($line);
  if ($got_anum ne $anum) { return undef; }
  return $values_str;
}

sub anum_to_values {
  my ($self, $anum) = @_;
  if (! ref $self) { $self = $self->instance; }
  my @values;
  my $values_str = $self->anum_to_values_str($anum);
  if (defined $values_str) {
    @values = $self->values_split($values_str);
  }
  return @values;
}

sub values_split {
  my ($self, $values_str) = @_;
  my @values = split /,/, $values_str;

  if ($self->{'use_bigint'}) {
    my $use_bigint = $self->{'use_bigint'};
    foreach my $value (@values) {
      if ($use_bigint eq 'always'
          || ($use_bigint eq 'if_necessary'
              && length($value) > UV_DECIMAL_DIGITS_MAX)) {
        $value = $self->bigint_class_load->new($value);  # mutate array
      }
    }
  }
  return @values;
}

# Return a class name which is the BigInt class to use for values from the
# stripped file.  This class has been loaded ready for use.
sub bigint_class_load {
  my ($self) = @_;
  return ($self->{'bigint_class_load'} ||= do {
    require Module::Load;
    my $bigint_class = $self->bigint_class;
    Module::Load::load($bigint_class);
    ### $bigint_class
    $bigint_class
  });
}

# Return a class name which is the BigInt class to use for values from the
# stripped file.  This class has not necessarily been loaded yet.
# Secret undocumented 'bigint_class' can change the BigInt class to use.
sub bigint_class {
  my ($self) = @_;
  return ($self->{'bigint_class'} ||= do {
    require Math::BigInt;
    eval { Math::BigInt->import (try => 'GMP') };
    'Math::BigInt'
  });
}

# C<($anum,$values_str) = Math::OEIS::Stripped-E<gt>line_split_anum($line)>
#
# $line is a line from the stripped file.  Return the A-number and a
# string of values.  Any leading comma like ",1,2,3" is removed from
# $values_str so that it's "1,2,3" etc.
#
# If C<$line> is a comment or unrecognised then return no values.
#
sub line_split_anum {
  my ($self, $line) = @_;
  ### Stripped line_split_anum(): $line
  $line =~ /^(A\d+)\s*,?([0-9].*)/
    or return;  # "#" comment lines or empty ",,"
  return ($1, $2);
}

1;
__END__

=for stopwords OEIS gunzipped lookup Oopery filename filehandle Ryde

=head1 NAME

Math::OEIS::Stripped - read the OEIS F<stripped> file

=head1 SYNOPSIS

 my @values = Math::OEIS::Stripped->anum_to_values('A123456');

=head1 DESCRIPTION

This is an interface to the OEIS F<stripped> file

=over

L<http://oeis.org/stripped.gz>

=back

downloaded and gunzipped to

=over

F<~/OEIS/stripped>

=back

The F<stripped> file contains each A-number and its sample values.  There's
usually about 180 characters worth of sample values but may be more or less.

The F<stripped> file is sorted by A-number so the C<anum_to_values()> lookup
is a text file binary search (currently implemented with L<Search::Dict>).

=head1 FUNCTIONS

=over

=item C<@values = Math::OEIS::Stripped-E<gt>anum_to_values($anum)>

=item C<$str = Math::OEIS::Stripped-E<gt>anum_to_values_str($anum)>

Return the values from the F<stripped> file for an C<$anum> string such as
"A000001".

C<anum_to_values()> returns a list of values, or an empty list if no such
A-number.  Values bigger than a usual Perl integer are automatically
converted to C<Math::BigInt> so as to preserve exact values.

C<anum_to_values_str()> returns a string like "1,2,3,4", or C<undef> if no
such A-number.  (The stripped file has a leading comma on its values list
but this is removed here for convenience of subsequent C<split> or similar.)

Draft sequences may have an empty values list ",,".  The return for them is
the same as "no such A-number", reckoning they have no values yet.

=item C<Math::OEIS::Stripped-E<gt>close()>

Close the F<stripped> file handle, if not already closed.

=back

=head2 Oopery

=over

=item C<$obj = Math::OEIS::Stripped-E<gt>new (key =E<gt> value, ...)>

Create and return a new C<Math::OEIS::Stripped> object to read an OEIS
F<stripped> file.  The optional key/value parameters can be

    filename => $filename         default ~/OEIS/stripped
    fh       => $filehandle

The default filename is F<~/OEIS/stripped>, or other directory per
F<Math::OEIS-E<gt>local_directories()>.  A different filename can be given,
or an open filehandle.  When a file handle is given the C<filename> may be
used for diagnostics and so can be helpfully given too.

=item C<@values = $obj-E<gt>anum_to_values($anum)>

=item C<$str = $obj-E<gt>anum_to_values_str($anum)>

Return the values from the F<stripped> file for an C<$anum> string such as
"A000001".

=item C<$filename = $obj-E<gt>filename()>

Return the filename from a given C<$obj> object.

=item C<$filename = Math::OEIS::Stripped-E<gt>default_filename()>

=item C<$filename = $obj-E<gt>default_filename()>

Return the default filename which is used if no C<filename> or C<fh> option
is given.  C<default_filename()> can be called either as a class method or
object method.

=item C<$obj-E<gt>close()>

Close the F<stripped> file handle, if not already closed.

=back

=head1 SEE ALSO

C<Math::OEIS>,
C<Math::OEIS::Names>

=head1 HOME PAGE

L<http://user42.tuxfamily.org/math-oeis/index.html>

=head1 LICENSE

Copyright 2010, 2011, 2012, 2013, 2014 Kevin Ryde

Math-OEIS is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; either version 3, or (at your option) any later
version.

Math-OEIS is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
Math-OEIS.  If not, see L<http://www.gnu.org/licenses/>.

=cut
