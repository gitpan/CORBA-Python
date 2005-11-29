use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'          => 'CORBA::Python',
    'VERSION_FROM'  => 'class.pm',
    'ABSTRACT'      => 'IDL compiler to Python mapping',
    'PREREQ_PM'     => {
                        'CORBA::IDL::node'  => 2.45,
                        'CORBA::C::include' => 2.43,
    },
    'PM'            => {
                        'class.pm'      => '$(INST_LIBDIR)/Python/class.pm',
                        'name.pm'       => '$(INST_LIBDIR)/Python/name.pm',
                        'literal.pm'    => '$(INST_LIBDIR)/Python/literal.pm',
                        'import.pm'     => '$(INST_LIBDIR)/Python/import.pm',
                        'client.pm'     => '$(INST_LIBDIR)/Python/client.pm',
                        'server.pm'     => '$(INST_LIBDIR)/Python/server.pm',
                        'cpy.pm'        => '$(INST_LIBDIR)/Python/cpy.pm',
                        'cpyext.pm'     => '$(INST_LIBDIR)/Python/cpyext.pm',
                        'cpyemb.pm'     => '$(INST_LIBDIR)/Python/cpyemb.pm',
                        'pyext.pm'      => '$(INST_LIBDIR)/Python/pyext.pm',
                        'pyemb.pm'      => '$(INST_LIBDIR)/Python/pyemb.pm',
    },
    'EXE_FILES'     => [
                        'idl2py.pl', 
                        'idl2pycli.pl', 
                        'idl2pysrv.pl', 
                        'idl2pyemb.pl', 
                        'idl2pyext.pl',
    ],
    'AUTHOR'        => "Francois PERRAD (francois.perrad\@gadz.org)",
    'dist'          => {
                        'COMPRESS'      => 'gzip',
                        'SUFFIX'        => '.gz',
    },
);

sub MY::install {
    package MY;
    my $script = shift->SUPER::install(@_);
    $script =~ s/install :: (.*)$/install :: $1 install_pyidl/m;
    $script .= <<"INSTALL";

install_pyidl :
\t\@python setup.py install

INSTALL

    return $script;
}
