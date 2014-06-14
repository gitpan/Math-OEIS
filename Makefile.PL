#!/usr/bin/perl -w

# Copyright 2014 Kevin Ryde

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


use 5.006;
use strict;
use ExtUtils::MakeMaker;

WriteMakefile
  (NAME         => 'Math::OEIS',
   ABSTRACT     => 'Things for Online Encyclopedia of Integer Sequences.',
   VERSION_FROM => 'lib/Math/OEIS.pm',
   PREREQ_PM    => {
                    'constant::defer' => 0,
                    'Class::Singleton' => 0,
                    'File::HomeDir' => 0,
                    'File::Spec' => 0,
                    'Module::Load' => 0,
                    'Search::Dict' => 0,

                    # only for testing
                    'Test::More' => 0,
                   },
   AUTHOR       => 'Kevin Ryde <user42_kevin@yahoo.com.au>',
   LICENSE      => 'gpl_3',
   SIGN         => 1,
   MIN_PERL_VERSION => '5.006',

   META_MERGE =>
   { resources =>
     { homepage => 'http://user42.tuxfamily.org/math-oeis/index.html',
       license  => 'http://www.gnu.org/licenses/gpl.html',
     },
     no_index => { directory=>['devel','xt'] },

     recommends =>
     { 'File::Map'    => 0,
       'Scalar::Util' => 0, # for weaken() in Perl 5.6
     },
   },
  );
