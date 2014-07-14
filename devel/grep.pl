#!/usr/bin/perl -w

# Copyright 2014 Kevin Ryde

# This file is part of Math-PlanePath.
#
# Math-PlanePath is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3, or (at your option) any later
# version.
#
# Math-PlanePath is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with Math-PlanePath.  If not, see <http://www.gnu.org/licenses/>.

use 5.006;
use strict;

{
  # grep with names

  require Math::OEIS::Grep;
  Math::OEIS::Grep->search(name => 'name one',
                           array=>['70760']);
  Math::OEIS::Grep->search(name => 'name two',
                           array=>['-70769800810139187843']);
  Math::OEIS::Grep->search(name => 'name two',
                           array=>[42894032],
                           verbose => 1);
  exit 0;
}

{
  require Math::OEIS::Grep;
  Math::OEIS::Grep->search(array=>['70760'],
                           use_mmap => 0);
  Math::OEIS::Grep->search(array=>['70769800810139187843'],
                           use_mmap => 0);
  Math::OEIS::Grep->search(array=>[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,2,1],
                           use_mmap => 0);
  exit 0;
}

{
  # average line length in the "stripped" file

  require Math::OEIS::Stripped;
  my $fh = Math::OEIS::Stripped->fh;
  my $len = 0;
  my $anum = '';
  my $count;
  my $total;
  while (my $line = readline $fh) {
    my ($anum, $values) = Math::OEIS::Stripped->line_split_anum($line)
      or next;
    $values =~ /\d/ or next;
    if (length($line) > $len) {
      $len = length($values);
    }
    $count++;
    $total += length($values);
  }
  my $average = $total/$count;
  print "max len $len in $anum average $average of $count\n";
  exit 0;
}

{
  my $fh;
  open $fh, '< /etc/passwd';
  print readline $fh;
  exit 0;
}
