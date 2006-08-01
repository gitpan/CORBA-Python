#!/usr/bin/perl

use strict;
use warnings;

use CORBA::IDL::parser30;
use CORBA::IDL::symbtab;
# visitors
use CORBA::IDL::repos_id;
use CORBA::C::literal;
use CORBA::C::name;
use CORBA::C::include;
use CORBA::C::type;
use CORBA::C::skel;
use CORBA::Python::name;
use CORBA::Python::import;
use CORBA::Python::literal;
use CORBA::Python::class;
use CORBA::Python::pyext;
use CORBA::Python::cpyext;

my $parser = new Parser;
$parser->YYData->{verbose_error} = 1;		# 0, 1
$parser->YYData->{verbose_warning} = 1;		# 0, 1
$parser->YYData->{verbose_info} = 1;		# 0, 1
$parser->YYData->{verbose_deprecated} = 0;	# 0, 1 (concerns only version '2.4' and upper)
$parser->YYData->{symbtab} = new CORBA::IDL::Symbtab($parser);
my $cflags = '-D__idl2pyext';
if ($Parser::IDL_version lt '3.0') {
	$cflags .= ' -D_PRE_3_0_COMPILER_';
}
if ($^O eq 'MSWin32') {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
#	$parser->YYData->{preprocessor} = 'CL /E /C /nologo ' . $cflags;	# Microsoft VC
} else {
	$parser->YYData->{preprocessor} = 'cpp -C ' . $cflags;
}
$parser->getopts("hi:J:Ovx");
if ($parser->YYData->{opt_v}) {
	print "CORBA::Python $CORBA::Python::class::VERSION\n";
	print "CORBA::C $CORBA::C::include::VERSION\n";
	print "CORBA::IDL $CORBA::IDL::node::VERSION\n";
	print "IDL $Parser::IDL_version\n";
	print "$0\n";
	print "Perl $] on $^O\n";
	exit;
}
if ($parser->YYData->{opt_h}) {
	use Pod::Usage;
	pod2usage(-verbose => 1);
}
$parser->YYData->{collision_allowed} = 1;
$parser->Run(@ARGV);
$parser->YYData->{symbtab}->CheckForward();
$parser->YYData->{symbtab}->CheckRepositoryID();

if (exists $parser->YYData->{nb_error}) {
	my $nb = $parser->YYData->{nb_error};
	print "$nb error(s).\n"
}
if (        $parser->YYData->{verbose_warning}
		and exists $parser->YYData->{nb_warning} ) {
	my $nb = $parser->YYData->{nb_warning};
	print "$nb warning(s).\n"
}
if (        $parser->YYData->{verbose_info}
		and exists $parser->YYData->{nb_info} ) {
	my $nb = $parser->YYData->{nb_info};
	print "$nb info(s).\n"
}
if (        $parser->YYData->{verbose_deprecated}
		and exists $parser->YYData->{nb_deprecated} ) {
	my $nb = $parser->YYData->{nb_deprecated};
	print "$nb deprecated(s).\n"
}

if (        exists $parser->YYData->{root}
		and ! exists $parser->YYData->{nb_error} ) {
	$parser->YYData->{root}->visit(new CORBA::IDL::repositoryIdVisitor($parser));
	if (        $Parser::IDL_version ge '3.0'
			and $parser->YYData->{opt_x} ) {
		$parser->YYData->{symbtab}->Export();
	}
	$parser->YYData->{root}->visit(new CORBA::C::nameVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::literalVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::lengthVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::typeVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::C::incskelVisitor($parser, '', ''));
	$parser->YYData->{root}->visit(new CORBA::C::skeletonVisitor($parser, ''));
	$parser->YYData->{root}->visit(new CORBA::Python::nameVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::Python::importVisitor($parser, 1));
	$parser->YYData->{root}->visit(new CORBA::Python::literalVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::Python::cPyExtendedVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::Python::cExtendedVisitor($parser));
	$parser->YYData->{root}->visit(new CORBA::Python::hExtendedVisitor($parser));
}

__END__

=head1 NAME

idl2pyext - IDL compiler to Python extension with C

=head1 SYNOPSIS

idl2pyext [options] I<spec>.idl

=head1 OPTIONS

All options are forwarded to C preprocessor, except -h -i -J -v -x.

With the GNU C Compatible Compiler Processor, useful options are :

=over 8

=item B<-D> I<name>

=item B<-D> I<name>=I<definition>

=item B<-I> I<directory>

=item B<-I->

=item B<-nostdinc>

=back

Specific options :

=over 8

=item B<-h>

Display help.

=item B<-i> I<directory>

Specify a path for import (only for version 3.0).

=item B<-J> I<directory>

Specify a path for Python package.

=item B<-O>

Enable old Python object model.

=item B<-v>

Display version.

=item B<-x>

Enable export (only for version 3.0).

=back

=head1 DESCRIPTION

B<idl2pyext> parses the given input file (IDL) and generates :

=over 4

=item *
a set of Python sources : an optional _I<spec>.py 
and I<pkg>/__init__.py for each package (in a standard tree)

=item *
a C c_I<pkg>module.c for each package

=item *
a include file hpy_I<spec>.h

=item *
a include file I<spec>.h

(following the language C mapping rules)

=item *
a C skeleton I<spec>.c (with automatic merge)

=item *
setup.py

=back

B<idl2pyext> is a Perl OO application what uses the visitor design pattern.
The parser is generated by Parse::Yapp.

B<idl2pyext> needs a B<cpp> executable.

CORBA Specifications, including IDL (Interface Language Definition) 
C Language Mapping and Python Language Mapping 
are available on E<lt>http://www.omg.org/E<gt>.

=head1 INSTALLATION

After standard Perl installation, you must install the Python package PyIDL :

    setup.py install

And copy the file F<corba.h> in Python24/include. 

=head1 TUTORIAL

=head2 EXAMPLE 1

Use F<ext1> as current directory.

The file F<Calc.idl> describes the interface of a simple calculator.

Nota : the IDL interface Calc is in the global scope.

First, copy additional files in current directory

    cp ../corba.h
    cp ../corba.c
    cp ../cpyhelper.c

Second, run :

    idl2pyext.pl Calc.idl

Third, in F<Calc.c> complete each methode between tag
START_EDIT and STOP_EDIT :

    // IDL : long Add(in long val1, in long val2);

    CORBA_long
    Calc_Add(
        Calc _o,
        CORBA_long val1, // in (fixed length)
        CORBA_long val2, // in (fixed length)
        CORBA_Environment * _ev
    )
    {
    /* START_EDIT (Calc_Add) */
        return val1 + val2;
    /* STOP_EDIT (Calc_Add) */
    }

Fourth, build :

    python setup.py build install

Finally, run Unit Test using the extension module :

    python tu_Calc.py

=head2 EXAMPLE 2

Use F<ext2> as current directory.

The file F<CalcCplx.idl> describes the interface of a complex calculator.

Nota : the IDL interface CalcCplx is in the IDL module Cplx.

Same steps as in previous example.

=head1 SEE ALSO

cpp, idl2html, idl2py, idl2pyemb

=head1 COPYRIGHT

(c) 2005 Francois PERRAD, France. All rights reserved.

This program and all CORBA::Perl modules are distributed
under the terms of the Artistic Licence.

=head1 AUTHOR

Francois PERRAD, francois.perrad@gadz.org

=cut

