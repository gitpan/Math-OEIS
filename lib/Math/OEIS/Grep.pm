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

package Math::OEIS::Grep;
use 5.006;
use strict;
use Carp 'croak';
use Math::OEIS::Names;
use Math::OEIS::Stripped;

our $VERSION = 4;

# uncomment this to run the ### lines
# use Smart::Comments;


my $stripped_mmap;

sub import {
  my $class = shift;
  my $arg = shift;
  if ($arg && $arg eq '-search') {
    $class->search(array=>\@_);
    exit 0;
  }
}

sub search {
  my $class = shift;
  my %h = (try_abs     => 1,
           verbose     => 0,
           use_mmap    => 'if_possible',
           max_matches => 10,
           @_);
  ### Grep search() ...
  ### $class

  my $name = $h{'name'};
  if (defined $name) {
    $name = "$name: ";
  } else {
    $name = '';
  }

  my $array = $h{'array'};
  if (! $array) {
    my $string = $h{'string'};
    $string =~ s/\s+/,/;
    $array = [ grep {defined} split /,+/, $string ];
  }
  unless ($array) {
    croak 'search() missing array=>[] parameter';
  }
  if (@$array == 0) {
    ### empty ...
    print "${name}no match empty list of values\n\n";
    return;
  }

  my $use_mmap = $h{'use_mmap'};

  if ($use_mmap && ! defined $stripped_mmap) {
    my $stripped_obj = Math::OEIS::Stripped->instance;
    my $stripped_filename = $stripped_obj->filename;
    if (eval {
      require File::Map;
      File::Map::map_file ($stripped_mmap, $stripped_filename);
      1;
    }) {
      if ($h{'verbose'}) {
        print "mmap stripped file, length ",length($stripped_mmap),"\n";
      }
    } else {
      my $err = $@;
      if ($use_mmap eq 'if_possible') {
        if ($h{'verbose'}) {
          print "cannot mmap, fallback to open: $err\n";
        }
        $use_mmap = 0;
      } else {
        croak "Cannot mmap $stripped_filename: $err";
      }
    }
  }

  my $fh;
  if (! $use_mmap) {
    $fh = Math::OEIS::Stripped->fh
      || croak "Cannot open ~/OEIS/stripped file";
  }

  {
    my $join = $array->[0];
    for (my $i = 1; $i <= $#$array && length($join) < 50; $i++) {
      $join .= ','.$array->[$i];
    }
    $name .= "match $join\n";
  }

  if (defined (my $value = _constant_array(@$array))) {
    if ($value != 0 && abs($value) <= 1000) {
      print "${name}constant $value\n\n";
      return;
    }
  }

  if (defined (my $diff = _constant_diff(@$array))) {
    if (abs($diff) < 20 && abs($array->[0]) < 100) {
      print "${name}constant difference $diff\n\n";
      return;
    }
  }

  if ($h{'verbose'}) {
    print $name;
    $name = '';
  }

  my $max_matches = $h{'max_matches'};
  my $count = 0;

  my $orig_array = $array;
  my $mung_desc = '';
 MUNG: foreach my $mung ('none',
                         'trim',
                         'negate',
                         ($h{'try_abs'} ? 'abs' : ()),
                         'half',
                         'quarter',
                         'double') {
    ### $mung
    last if $count;  # no more munging when found a match

    if ($mung eq 'none') {

    } elsif ($mung eq 'trim') {
      $mung_desc = "[TRIMMED START]\n";
      $array = [ @$orig_array ]; # copy
      while (@$array && $array->[0] == 0) {
        shift @$array;
      }
      if (@$array) {
        shift @$array;
      }
      if (_any_nonzero($array) &&
          (@$array >= 3 || length(join(',',@$array)) >= 5)) {
        $orig_array = $array;
      } else {
        ### too few values to trim ...
        next MUNG;
      }

    } elsif ($mung eq 'negate') {
      $mung_desc = "[NEGATED]\n";
      $array = [ map { my $value = $_;
                       unless ($value =~ s/^-//) {
                         $value = "-$value";
                       }
                       $value
                     } @$orig_array ];

    } elsif ($mung eq 'half') {
      $mung_desc = "[HALF]\n";
      $array = [ map {
        my $value = _to_bigint($_);
        if ($value % 2) {
          if ($h{'verbose'}) {
            print "not all even, cannot halve\n";
          }
          next MUNG;
        }
        $value/2
      } @$orig_array ];

    } elsif ($mung eq 'quarter') {
      $mung_desc = "[QUARTER]\n";
      $array = [ map {
        my $value = _to_bigint($_);
        if ($value % 4) {
          if ($h{'verbose'}) {
            print "not all multiple of 4, cannot quarter\n";
          }
          next MUNG;
        }
        $value/4
      } @$orig_array ];

    } elsif ($mung eq 'double') {
      $mung_desc = "[DOUBLE]\n";
      $array = [ map {2*_to_bigint($_)} @$orig_array ];

    } elsif ($mung eq 'abs') {
      $mung_desc = "[ABSOLUTE VALUES]\n";
      my $any_negative = 0;
      $array = [ map { my $abs = $_;
                       $any_negative |= ($abs =~ s/^-//);
                       $abs
                     } @$orig_array ];
      if (! $any_negative) {
        if ($h{'verbose'}) {
          print "no negatives to absolutize\n";
        }
        next;
      }
    }
    ### $use_mmap

    my $re = $class->array_to_regexp($array);

    if ($use_mmap) {
      pos($stripped_mmap) = 0;
    } else {
      seek $fh, 0, 0
        or croak "Error seeking stripped file: ",$!;
    }
    my $block = '';
    my $extra = '';
  SEARCH: for (;;) {
      my $line;
      if ($use_mmap) {

        # using regexp only
        $stripped_mmap =~ /$re/g or last SEARCH;
        my $found_pos = pos($stripped_mmap)-1;
        my $start = rindex($stripped_mmap,"\n",$found_pos) + 1;
        my $end = index($stripped_mmap,"\n",$found_pos);
        pos($stripped_mmap) = $end;
        $line = substr($stripped_mmap, $start, $end-$start);
        ### $found_pos
        ### $start
        ### $end

        # my $pos = 0;
        # using combination index() and regexp
        # for (;;) {
        #   $stripped_mmap =~ /$re/g or last SEARCH;
        #   my $found_pos = pos($stripped_mmap)-1;
        #   # my $found_pos = index($stripped_mmap,$fixed,$pos);
        #   # if ($found_pos < 0) { last SEARCH; }
        #
        #   my $start = rindex($stripped_mmap,"\n",$found_pos) + 1;
        #   my $end = index($stripped_mmap,"\n",$found_pos);
        #   $pos = $end;
        #   $line = substr($stripped_mmap, $start, $end-$start);
        #   last if $line =~ $re;
        # }

      } else {
        ### block reads ...

        for (;;) {
          if ($block =~ /$re/g) {
            my $found_pos = pos($block)-1;
            my $start = rindex($block,"\n",$found_pos) + 1;
            my $end = index($block,"\n",$found_pos);
            pos($block) = $end;
            $line = substr($block, $start, $end-$start);
            last;
          }
          $block = _read_block_lines($fh, $extra);
          defined $block or last SEARCH;

          # or line by line
          # $line = readline $fh;
          # defined $line or last SEARCH;
        }
      }

      if (defined $max_matches && $count >= $max_matches) {
        print "... and more matches\n";
        last SEARCH;
      }

      my ($anum) = ($line =~ /^(A\d+)/);
      $anum || die "oops, A-number not matched in line: ",$line;

      print $name;
      $name = '';

      print $mung_desc;
      $mung_desc = '';

      my $anum_name = Math::OEIS::Names->anum_to_name($anum);
      if (! defined $anum_name) { $anum_name = '[unknown name]'; }
      print "$anum $anum_name\n";

      print "$line\n";
      $count++;
    }
  }
  if ($count == 0) {
    if ($h{'verbose'}) {
      print "no matches\n";
    }
  }
  if ($count || $h{'verbose'}) {
    print "\n";
  }
}

# Read a block of multiple lines from $fh.
# The return is a string $block, or undef at EOF.
# $extra in $_[1] is used to hold a partial line.
sub _read_block_lines {
  my ($fh, $extra) = @_;
  my $block = $extra;
  for (;;) {
    my $len = read($fh, $block, 65536,
                   length($block)); # append to $block
    if (! defined $len) {
      croak "Error seeking stripped file: ",$!;
    }
    if (! $len) {
      # EOF
      $_[1] = '';
      if (length ($block)) {
        return $block;
      } else {
        return undef;
      }
    }
    my $end = rindex $block, "\n";
    if ($end >= 0) {
      # keep partial line in $extra
      $_[1] = substr ($block, $end);                  # partial line
      substr($block, $end, length($block)-$end, '');  # truncate block
      return $block;
    }
    # no end of line in $block, keep reading to find one
  }
}

# $str =~ s/^\s+//;
# $str =~ s/\s+$//;
# split /\s*,\s*/, $str
sub array_to_regexp {
  my ($self, $array) = @_;
  my $re = '';
  my $close = 0;
  foreach my $value (@$array) {
    if (length($re) > 400) {  # don't make a huge regexp
      last;
    }
    $re .= ',';
    if (length($re) > 60) {   # must match 60 chars, then OEIS can end
      $re .= '(?:';
      $close++;
    }
    $re .= $value;
  }
  $re .= ')?' x $close;
  $re .= "[,\r\n]";
  ### $re
  return $re;
}

# constant_diff($a,$b,$c,...)
# If all the given values have a constant difference then return that amount.
# Otherwise return undef.
#
sub _constant_diff {
  my $diff = shift;
  unless (@_) {
    return undef;
  }
  my $value = shift;
  $diff = $value - $diff;
  while (@_) {
    my $next_value = shift;
    if ($next_value - $value != $diff) {
      return undef;
    }
    $value = $next_value;
  }
  return $diff;
}

# _constant_array($a,$b,$c,...)
# If all the given values are all equal then return that value.
# Otherwise return undef.
#
sub _constant_array {
  my $value = shift;
  while (@_) {
    my $next_value = shift;
    if ($next_value != $value) {
      return undef;
    }
  }
  return $value;
}

# return true if the array in $aref has any non-zero entries
sub _any_nonzero {
  my ($aref) = @_;
  while (@$aref) {
    if (shift @$aref) { return 1; }
  }
  return 0;
}

{
  my $bigint_class;
  my $length_limit = length(~0) - 2;
  sub _to_bigint {
    my ($n) = @_;
    if (length($n) < $length_limit) {
      return $n;
    }
    $bigint_class ||= do {
      # Crib note: don't change the back-end if already loaded
      require Math::BigInt;
      'Math::BigInt'
    };
    # stringize as a workaround for a bug where Math::BigInt::GMP
    # incorrectly converts UV numbers bigger than IV
    return $bigint_class->new("$n");
  }
}

1;
__END__

=for stopwords OEIS mmap Mmap arrayref Eg Ryde

=head1 NAME

Math::OEIS::Grep - search for numbers in OEIS F<stripped> file

=head1 SYNOPSIS

 use Math::OEIS::Grep;
 Math::OEIS::Grep->search (array => [ 8,13,21,34,55,89 ]);
 # prints matches found

 # command line
 # perl -MMath::OEIS::Grep=-search,123,456,789

=head1 DESCRIPTION

This module searches for numbers in a downloaded copy of the OEIS
F<stripped> file.  See L<Math::OEIS::Stripped> on how to get that file.

This grep is an alternative to the OEIS web site search and is good if
offline or for mechanically trying a large numbers of searches.

The exact form of the results printout and transformations is not settled.
The intention is to do something sensible to find given numbers.

The OEIS F<names> file is used to show the name of a matched sequence, if
that file is available.  See L<Math::OEIS::Names>.

=head2 Details

When a match is found it's generally necessary to examine the sequence
definition manually to check the relevance.  It might be exactly the formula
you're seeking, or it might be mere coincidence, or it might be an
interesting unsuspected connection.

If the given array of values is longer than the OEIS samples it will still
match.  The first few values must match but then the match stops at either
the end of the given values or the end of the OEIS samples, whichever comes
first.

An array of constant values or small constant difference is recognised and
not searched since there's usually too many matches and the OEIS sequence
which is a constant or constant difference may not be the first match.

C<File::Map> is used to access the F<stripped> file for searching, if that
module is available.  This is recommended since C<mmap> is a speedup of
about 2x over plain reading (by blocks).

The OEIS search hints at L<http://oeis.org/hints.html> note that it can be
worth skipping an initial value or two in case you have a different idea of
a start, but then a known sequence.  There's a slight attempt to automate
that here by stripping leading zeros and one initial value if no full match.

It may be worth dividing out a small common factor.  There's attempts here
to automate that here by searching for /2 and /4 if no exact match (and
doubling *2 too in fact).  Maybe more divisions could be attempted, even a
full GCD.  In practice sequences with common factors are often present when
arises naturally from a sequence definition.

=head1 FUNCTIONS

=over

=item C<Math::OEIS::Grep-E<gt>search (array =E<gt> $aref, ...)>

Print matches of the given C<array> values in the OEIS F<stripped> file.
The key/value pairs can be

    array       => $arrayref (mandatory)
    name        => $string
    max_matches => $integer (default 10)

C<array> is an arrayref of values to search for.  This parameter must be
given.

C<name> is printed if matches are found.  When doing many searches this
identify which one has matched.  Eg.

    name => "case d=123",

C<max_matches> limits the number of sequences returned.  This is intended as
a protection against a large number of matches from some small list or
frequently occurring values.

=back

=head1 COMMAND LINE

The module C<import> accepts a C<-search> option which is designed for use
from the command line

    perl -MMath::OEIS::Grep=-search,123,456,789
    # search and then exit perl

In Emacs see C<oeis.el> to run such a command on numbers entered or at
point, L<http://user42.tuxfamily.org/oeis-el/index.html>.

=over

=back

=head1 SEE ALSO

L<Math::OEIS>,
L<Math::OEIS::Stripped>,
L<File::Map>

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
