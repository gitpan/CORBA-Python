use strict;

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

use CORBA::Python::class;

package CORBA::Python::cPyEmbeddedVisitor;

use base qw(CORBA::Python::classVisitor);

use File::Basename;
use File::Path;
use POSIX qw(ctime);

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {};
	bless($self, $class);
	my ($parser) = @_;
	$self->{srcname} = $parser->YYData->{srcname};
	$self->{srcname_size} = $parser->YYData->{srcname_size};
	$self->{srcname_mtime} = $parser->YYData->{srcname_mtime};
	$self->{symbtab} = $parser->YYData->{symbtab};
	$self->{client} = 1;
	if (exists $parser->YYData->{opt_J}) {
		$self->{base_package} = $parser->YYData->{opt_J};
	} else {
		$self->{base_package} = "";
	}
	$self->{done_hash} = {};
	$self->{marshal} = 0;
	$self->{stringify} = 1;
	$self->{compare} = 1;
	$self->{id} = 1;
	$self->{old_object} = exists $parser->YYData->{opt_O};
	$self->{indent} = "";
	$self->{out} = undef;
	$self->{import} = "import PyIDL as CORBA\n"
					. "\n";
	$self->{scope} = undef;
	return $self;
}

sub open_stream {
	my $self = shift;
	my ($filename, $node) = @_;
	my $dirname = dirname($filename);
	if ($dirname ne ".") {
		unless (-d $dirname) {
			mkpath($dirname)
					or die "can't create $dirname ($!).\n";
		}
	}
	my $py_module = $filename;
	$py_module =~ s/\.py$//;
	$py_module =~ s/\//\./g;
	$self->{module} = $py_module;
	$self->{out} = new IO::File "> $filename"
			or die "can't open $filename ($!).\n";
	$self->{filename} = $filename;
	my $FH = $self->{out};
	print $FH "#   This file was generated (by ",basename($0),"). DO NOT modify it.\n";
	print $FH "# From file : ",$self->{srcname},", ",$self->{srcname_size}," octets, ",POSIX::ctime($self->{srcname_mtime});
	print $FH "\n";
	print $FH $self->{import};
	foreach my $name (sort keys %{$node->{py_import}}) {
		if ($name eq '::CORBA') {
			next;
		}
		if ( $name eq '::' or $name eq '' ) {
			if ($self->{base_package}) {
				$name = $self->{base_package};
				$name =~ s/\//\./g;
			} else {
				my $basename = basename($self->{srcname}, ".idl"); 
				$basename =~ s/\./_/g;
				$name = "_" . $basename;
			}
		} else {
			$name =~ s/^:://;
			$name =~ s/::/\./g;
			if ($self->{base_package}) {
				$name = $self->{base_package} . "." . $name;
				$name =~ s/\//\./g;
			}
		}
		print $FH "import ",$name,"\n";
	}
}

#
#	3.5		OMG IDL Specification		(inherited)
#

#
#	3.7		Module Declaration			(inherited)
#

#
#	3.8		Interface Declaration
#

sub visitRegularInterface {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	$self->{indent} = "    ";
	print $FH "\n";
	if ($self->{old_object}) {
		print $FH "class ",$node->{py_name};
		if (exists $node->{inheritance} and exists $node->{inheritance}->{list_interface}) {
			print $FH "(";
			my $first = 1;
			foreach (@{$node->{inheritance}->{list_interface}}) {
				print $FH ", " unless ($first);
				my $base = $self->_get_defn($_); 
				print $FH $self->_get_scoped_name($base, $node);
				$first = 0;
			}
			print $FH ")";
		}
		print $FH ":\n";
	} else {
		print $FH "class ",$node->{py_name},"(";
		if (exists $node->{inheritance} and exists $node->{inheritance}->{list_interface}) {
			my $first = 1;
			foreach (@{$node->{inheritance}->{list_interface}}) {
				print $FH ", " unless ($first);
				my $base = $self->_get_defn($_); 
				print $FH $self->_get_scoped_name($base, $node);
				$first = 0;
			}
		} else {
			print $FH "object";
		}
		print $FH "):\n";
	}
	print $FH "    \"\"\" Interface: ",$node->{repos_id}," \"\"\"\n";
	print $FH "\n";
	print $FH "    def __init__(self):\n";
	print $FH "        pass\n";
	print $FH "\n";
	$self->{repos_id} = $node->{repos_id};
	foreach (@{$node->{list_decl}}) {
		my $defn = $self->_get_defn($_);
		if (	   $defn->isa('Operation')
				or $defn->isa('Attributes') ) {
			next;
		}
		$defn->visit($self);
	}
	if ($self->{id}) {
		print $FH "    def _get_id(self):\n";
		print $FH "        return '",$node->{repos_id},"'\n";
		print $FH "\n";
		print $FH "    corba_id = property(fget=_get_id)\n";
		print $FH "\n";
	}
	foreach (sort keys %{$node->{hash_attribute_operation}}) {
		my $defn = $self->_get_defn(${$node->{hash_attribute_operation}}{$_});
		$defn->visit($self);
	}
	print $FH "\n";
	$self->{indent} = "";
}

sub visitAbstractInterface {
	my $self = shift;
	my($node) = @_;
	my $FH = $self->{out};
	$self->{indent} = "    ";
	print $FH "\n";
	if ($self->{old_object}) {
		print $FH "class ",$node->{py_name};
		if (exists $node->{inheritance} and exists $node->{inheritance}->{list_interface}) {
			print $FH "(";
			my $first = 1;
			foreach (@{$node->{inheritance}->{list_interface}}) {
				print $FH ", " unless ($first);
				my $base = $self->_get_defn($_); 
				print $FH $self->_get_scoped_name($base, $node);
				$first = 0;
			}
			print $FH ")";
		}
		print $FH ":\n";
	} else {
		print $FH "class ",$node->{py_name},"(";
		if (exists $node->{inheritance} and exists $node->{inheritance}->{list_interface}) {
			my $first = 1;
			foreach (@{$node->{inheritance}->{list_interface}}) {
				print $FH ", " unless ($first);
				my $base = $self->_get_defn($_); 
				print $FH $self->_get_scoped_name($base, $node);
				$first = 0;
			}
		} else {
			print $FH "object";
		}
		print $FH "):\n";
	}
	print $FH "    \"\"\" Abstract Interface: ",$node->{repos_id}," \"\"\"\n";
	print $FH "\n";
	print $FH "    def __init__(self):\n";
	print $FH "        pass\n";
	print $FH "\n";
	$self->{repos_id} = $node->{repos_id};
	foreach (@{$node->{list_decl}}) {
		my $defn = $self->_get_defn($_);
		if (	   $defn->isa('Operation')
				or $defn->isa('Attributes') ) {
			next;
		}
		$defn->visit($self);
	}
	foreach (sort keys %{$node->{hash_attribute_operation}}) {
		my $defn = $self->_get_defn(${$node->{hash_attribute_operation}}{$_});
		$defn->visit($self);
	}
	$self->{indent} = "";
}

#
#	3.9		Value Declaration			(inherited)
#

#
#	3.10	Constant Declaration		(inherited)
#

#
#	3.11	Type Declaration			(inherited)
#

#
#	3.12	Exception Declaration		(inherited)
#

#
#	3.13	Operation Declaration
#

sub visitOperation {
	my $self = shift;
	my ($node) = @_;
	my $FH = $self->{out};
	print $FH "#   def ",$node->{py_name},"(self";
	foreach (@{$node->{list_param}}) {		# paramater
		if ( $_->{attr} eq 'in' or $_->{attr} eq 'inout') {
			print $FH ", ",$_->{py_name};
		}
	}
	print $FH "): pass\n";
}

#
#	3.14	Attribute Declaration		(inherited)
#

1;

