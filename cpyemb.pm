use strict;
use POSIX qw(ctime);

#
#			Interface Definition Language (OMG IDL CORBA v3.0)
#

use CORBA::Python::cpy;

package CORBA::Python::cEmbeddedVisitor;

use base qw(CORBA::Python::CPyVisitor);

use File::Basename;
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
	$self->{old_object} = exists $parser->YYData->{opt_O};
	$self->{embedded} = 1;
	$self->{num_key} = 'num_cpyemb';
	$self->{error} = "goto err";
	$self->{assert} = 1;
	$self->{num_typedef} = 0;
	if (exists $parser->YYData->{opt_J}) {
		$self->{base_package} = $parser->YYData->{opt_J};
	} else {
		$self->{base_package} = "";
	}
	$self->{done_hash} = {};
	my $basename = basename($self->{srcname}, ".idl"); 
	my $filename = $basename . ".c";
	$self->open_stream($filename);
	return $self;
}

#
#	3.5		OMG IDL Specification
#

sub visitSpecification {
	my $self = shift;
	my($node) = @_;
	my $basename = basename($self->{srcname}, ".idl"); 
	my $py_name = "_" . $basename;
	$py_name =~ s/\./_/g;
	$self->{root_module} = $py_name;
	my $FH = $self->{out};
	print $FH "/* This file was generated (by ",basename($0),"). DO NOT modify it */\n";
	print $FH "// From file : ",$self->{srcname},", ",$self->{srcname_size}," octets, ",POSIX::ctime($self->{srcname_mtime});
	print $FH "\n";
	print $FH "#include \"Python.h\"\n";
	if ($self->{assert}) {
		print $FH "#include <assert.h>\n";
	}
	print $FH "#include \"",$basename,".h\"\n";
	print $FH "\n";
	print $FH "extern PyObject *find_class(PyObject *module, char *classname);\n";
	print $FH "extern PyObject *lookup_itf(char *repos_id);\n";
	print $FH "extern int parse_object(PyObject *obj, char *format, void *addr);\n";
	print $FH "\n";
	print $FH "\n";
	my $empty = 1;
	foreach (@{$node->{list_decl}}) {
		my $defn = $self->_get_defn($_);
		unless (   $defn->isa('Modules')
				or $defn->isa('Import') ) {
			$empty = 0;
		}
	}
	unless ($empty) {
		print $FH "static PyObject* _mod_",$self->{root_module}," = NULL;\n";
		print $FH "\n";
	}
	foreach (@{$node->{list_decl}}) {
		$self->_get_defn($_)->visit($self);
	}
	print $FH "/* End Of File : ",$self->{filename}," */\n";
	close $FH;
}

#
#	3.7		Module Declaration			(inherited)
#

#
#	3.8		Interface Declaration
#

sub visitBaseInterface {
	# empty
}

sub visitRegularInterface {
	my $self = shift;
	my ($node) = @_;
	my $FH = $self->{out};
	print $FH "/*\n";
	print $FH " * begin of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	foreach (@{$node->{list_decl}}) {
		my $defn = $self->_get_defn($_);
		if (	   $defn->isa('Operation')
				or $defn->isa('Attributes') ) {
			next;
		}
		$defn->visit($self);
	}
	if ($self->{srcname} eq $node->{filename}) {
		my ($c_mod, $py_mod, $classname) = $self->_split_name($node);
		print $FH "\n";
		print $FH "PyObject * _new_",$node->{c_name},"(void)\n";
		print $FH "{\n";
		print $FH "\tPyObject* _cls_",$node->{c_name},";\n";
		print $FH "\tPyObject* _obj_",$node->{c_name},";\n";
		print $FH "\t_cls_",$node->{c_name}," = lookup_itf(\"",$node->{repos_id},"\"); // New reference\n";
		if ($self->{assert}) {
			print $FH "\tassert(NULL != _cls_",$node->{c_name},");\n";
		}
		print $FH "\tif (NULL == _cls_",$node->{c_name},") {\n";
		print $FH "\t\treturn NULL;\n";
		print $FH "\t} else {\n";
		if ($self->{old_object}) {
			print $FH "\t\t_obj_",$node->{c_name}," = PyInstance_New(_cls_",$node->{c_name},", NULL, NULL); // New reference\n";
		} else {  
			print $FH "\t\t_obj_",$node->{c_name}," = PyObject_Call(_cls_",$node->{c_name},", PyTuple_New(0), NULL);\n";
		}  
		if ($self->{assert}) {
			print $FH "\t\tassert(NULL != _obj_",$node->{c_name},");\n";
		}
		print $FH "\t\treturn _obj_",$node->{c_name},";\n";
		print $FH "\t}\n";
		print $FH "}\n";
		print $FH "\n";
		if (keys %{$node->{hash_attribute_operation}}) {
			$self->{itf} = $node->{c_name};
			$self->{repos_id} = $node->{repos_id};
			print $FH "\t/*-- methods --*/\n";
			print $FH "\n";
			foreach (values %{$node->{hash_attribute_operation}}) {
				$self->_get_defn($_)->visit($self);
			}
			print $FH "\n";
		}
	}
	print $FH "/*\n";
	print $FH " * end of interface ",$node->{c_name},"\n";
	print $FH " */\n";
	print $FH "\n";
}

sub visitAbstractInterface {
	my $self = shift;
	my ($node) = @_;
	my $FH = $self->{out};
	print $FH "/*\n";
	print $FH " * begin of abstract interface ",$node->{c_name},"\n";
	print $FH " */\n";
	foreach (@{$node->{list_decl}}) {
		my $defn = $self->_get_defn($_);
		if (	   $defn->isa('Operation')
				or $defn->isa('Attributes') ) {
			next;
		}
		$defn->visit($self);
	}
	print $FH "\n";
	print $FH "/*\n";
	print $FH " * end of abstract interface ",$node->{c_name},"\n";
	print $FH " */\n";
	print $FH "\n";
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
	$self->SUPER::visitOperation(@_);
	my ($node) = @_;
	my $label_err = undef;
	my $type = $self->_get_defn($node->{type});
	unless ($type->isa("VoidType")) {				# return
		$label_err = $type->{length};
	}
	foreach (@{$node->{list_in}}) {					# paramater
		my $type = $self->_get_defn($_->{type});
	}
	foreach (@{$node->{list_inout}}) {				# paramater
		my $type = $self->_get_defn($_->{type});
		$label_err ||= $type->{length};
	}
	foreach (@{$node->{list_out}}) {				# paramater
		my $type = $self->_get_defn($_->{type});
		$label_err ||= $type->{length};
	}
	my $nb_user_except = 0;
	if (exists $node->{list_raise}) {
		$nb_user_except = @{$node->{list_raise}};
		foreach (@{$node->{list_raise}}) {			# exception
			my $defn = $self->_get_defn($_);
			$label_err ||= $defn->{length};
		}
	}
	my $FH = $self->{out};
	print $FH "\n";
	print $FH $node->{c_arg},"\n";
	print $FH $self->{itf},"_",$node->{c_name},"(\n";
	print $FH "\t",$self->{itf}," _o,\n";
	foreach (@{$node->{list_param}}) {	# paramater
		my $type = $self->_get_defn($_->{type});
		print $FH "\t",$_->{c_arg},", // ",$_->{attr};
			print $FH " (variable length)\n" if (defined $type->{length});
			print $FH " (fixed length)\n" unless (defined $type->{length});
	}
	if (exists $node->{list_context}) {
		print $FH "\tCORBA_Context _ctx,\n";
	}
	print $FH "\tCORBA_Environment * _ev\n";
	print $FH ")\n";
	print $FH "{\n";
	if (exists $node->{list_raise}) {
		print $FH "#ifdef CORBA_THREADED\n";
		foreach (@{$node->{list_raise}}) {	# exception
			my $defn = $self->_get_defn($_);
			print $FH "\t",$defn->{c_name}," *_",$defn->{c_name}," NULL;\n";
		}
		print $FH "#else\n";
		foreach (@{$node->{list_raise}}) {	# exception
			my $defn = $self->_get_defn($_);
			print $FH "\tstatic ",$defn->{c_name}," __",$defn->{c_name},";\n";
			print $FH "\t",$defn->{c_name}," *_",$defn->{c_name}," = &__",$defn->{c_name},";\n";
		}
		print $FH "#endif\n";
	}
	unless ($type->isa("VoidType")) {
		if (($type->isa("StructType") or $type->isa("UnionType"))
		 and defined $type->{length}) {
			print $FH "\t",$type->{c_name}," * _ret;\n";
		} else {
			print $FH "\t",$type->{c_name}," _ret;\n";
		}
	}
	print $FH "\tPyObject * _obj;\n";
	print $FH "\tPyObject * _result = NULL;\n";
	print $FH "\tPyObject * _exc = NULL;\n";
	my @fmt_in = ();
	my @fmt_out = ();         
	my $args_in = "";
	my $args_out = "";
	unless ($type->isa("VoidType")) {
		my $fmt = CORBA::Python::CPy_format->NameAttr($self->{symbtab}, $type);
		if ($fmt eq "O") {
			print $FH "\tPyObject * __ret;\n";
			$args_out .= ", &__ret"
		} else {
			$args_out .= ", &_ret"
		}
		push @fmt_out, $fmt;
	}
	foreach (@{$node->{list_param}}) {	# parameter
		my $type = $self->_get_defn($_->{type});
		my $fmt = CORBA::Python::CPy_format->NameAttr($self->{symbtab}, $type);
		if ($fmt eq "O") {
			print $FH "\tPyObject * _",$_->{c_name}," = NULL;\n";
		}
		if      ($_->{attr} eq "in") {
			if ($fmt eq "O") {
				$args_in .= ", _" . $_->{c_name};
			} else {
				$args_in .= ", " . $_->{c_name};
			}
			push @fmt_in, $fmt;
		} elsif ($_->{attr} eq "inout") {
			if ($fmt eq "O") {
				$args_in .= ", _" . $_->{c_name};
				$args_out .= ", &_" . $_->{c_name};
			} else {
				$args_in .= ", *" . $_->{c_name};
				$args_out .= ", " . $_->{c_name};
			}
			push @fmt_in, $fmt;
			push @fmt_out, $fmt;
		} elsif ($_->{attr} eq "out") {
			if ($fmt eq "O") {
				$args_out .= ", &_" . $_->{c_name};
			} else {
				$args_out .= ", " . $_->{c_name};
			}
			push @fmt_out, $fmt;
		}
	}
	print $FH "\tCORBA_Environment __ev;\n";
	print $FH "\n";
	foreach (@{$node->{list_param}}) {	# parameter
		my $type = $self->_get_defn($_->{type});
		my $fmt = CORBA::Python::CPy_format->NameAttr($self->{symbtab}, $type);
		if (	    $_->{attr} eq 'out'
				and $fmt eq "O"
				and defined $type->{length} ) {
			print $FH "\t",CORBA::Python::Cfree_out->NameAttr($self->{symbtab}, $type),$_->{c_name}," = NULL;\n";
		}
	}
	print $FH "\n";
	print $FH "\tif (NULL == _ev) _ev = &__ev;\n";
	print $FH "\t_ev->_major = CORBA_NO_EXCEPTION;\n";
	unless ($type->isa("VoidType")) {
		if (($type->isa("StructType") or $type->isa("UnionType"))
		 and defined $type->{length}) {
			print $FH "\t_ret = ",$type->{c_name},"__alloc(1);\n";
			if ($self->{assert}) {
				print $FH "\tassert(NULL != _ret);\n";
			}
			print $FH "\tif (NULL == _ret) {\n";
			print $FH "\t\tCORBA_exception_set_system(_ev, ex_CORBA_NO_MEMORY, CORBA_COMPLETED_NO);\n";
			print $FH "\t\tgoto err;\n";
			print $FH "\t}\n";
		} else {
			print $FH "\tmemset(&_ret, 0, sizeof _ret);\n",
		}
	}
	print $FH "\n";
	print $FH "\tif (NULL == _o) {\n";
	print $FH "\t\t_obj = _new_",$self->{itf},"(); // New reference\n";
	print $FH "\t\tif (NULL == _obj) {\n";
	print $FH "\t\t\tCORBA_exception_set_system(_ev, ex_CORBA_OBJECT_NOT_EXIST, CORBA_COMPLETED_NO);\n";
	print $FH "\t\t\tgoto err;\n";
	print $FH "\t\t}\n";
	print $FH "\t} else {\n";
	print $FH "\t\t_obj = (PyObject *)_o;\n";
	print $FH "\t}\n";
	if (exists $node->{list_raise}) {
		foreach (@{$node->{list_raise}}) {	# exception
			my $defn = $self->_get_defn($_);
			my ($c_mod, $py_mod, $classname) = $self->_split_name($defn);
			print $FH "\tif (NULL == _mod_",$c_mod,") {\n";
			print $FH "\t\t_mod_",$c_mod," = PyImport_ImportModule(\"",$py_mod,"\"); // New reference\n";
			print $FH "\t}\n";
			print $FH "\tif (NULL == _cls_",$defn->{c_name},") {\n";
			print $FH "\t\t_cls_",$defn->{c_name}," = find_class(_mod_",$c_mod,", \"",$classname,"\"); // New reference\n";
			print $FH "\t}\n";
			if ($self->{assert}) {
				print $FH "\tassert(NULL != _cls_",$defn->{c_name},");\n";
			}
			print $FH "\tif (NULL == _cls_",$defn->{c_name},") {\n";
			print $FH "\t\tCORBA_exception_set_system(_ev, ex_CORBA_OBJECT_NOT_EXIST, CORBA_COMPLETED_NO);\n";
			print $FH "\t\tgoto err;\n";
			print $FH "\t}\n";
		}
	}
	foreach (@{$node->{list_param}}) {	# parameter
		next if ($_->{attr} eq "out");
		my $type = $self->_get_defn($_->{type});
		my $fmt = CORBA::Python::CPy_format->NameAttr($self->{symbtab}, $type);
		if ($fmt eq "O") {
			print $FH "\tPYOBJ_FROM_",$type->{c_name},"(_",$_->{c_name},", ",CORBA::Python::Cobj_from->NameAttr($self->{symbtab}, $type, $_->{attr}), $_->{c_name},");\n";
		}
	}
	print $FH "\n";
	if (scalar @fmt_in) {
		print $FH "\t_result = PyObject_CallMethod(_obj, \"",$node->{py_name},"\", \"",@fmt_in,"\"",$args_in,"); // New reference\n";
	} else {
		print $FH "\t_result = PyObject_CallMethod(_obj, \"",$node->{py_name},"\", NULL); // New reference\n";
	}
	print $FH "\n";
	print $FH "\tif (NULL != _result) {\n";
	if (scalar @fmt_out) {
		print $FH "\t\tif (_result == Py_None) {\n";
		print $FH "\t\t\tCORBA_exception_set_system(_ev, ex_CORBA_NO_IMPLEMENT, CORBA_COMPLETED_MAYBE);\n";
		print $FH "\t\t\tgoto err;\n";
		print $FH "\t\t}\n";
		my $fmt_out = join "", @fmt_out; 
		if ($fmt_out eq "O") {
			 $args_out =~ s/^, &//;
			print $FH "\t\t",$args_out," = _result;\n";
		} else {
			if (scalar(@fmt_out) == 1) {
				print $FH "\t\tif (!parse_object(_result, \"",@fmt_out,"\"",$args_out,")) {\n";
				if ($self->{assert}) {
					print $FH "\t\t\tassert(0 == \"",$self->{itf},"_",$node->{c_name}," parse_object\");\n";
				}
			} else {
				print $FH "\t\tif (!PyArg_ParseTuple(_result, \"",@fmt_out,"\"",$args_out,")) {\n";
				if ($self->{assert}) {
					print $FH "\t\t\tassert(0 == \"",$self->{itf},"_",$node->{c_name}," PyArg_ParseTuple ",@fmt_out,"\");\n";
				}
			}
			print $FH "\t\t\tgoto err;\n";
			print $FH "\t\t}\n";
		}
	}
	unless ($type->isa("VoidType")) {
			my $fmt = CORBA::Python::CPy_format->NameAttr($self->{symbtab}, $type);
			if ($fmt eq "O") {
				print $FH "\t\tPYOBJ_CHECK_",$type->{c_name},"(__ret);\n";
				print $FH "\t\tPYOBJ_AS_",$type->{c_name},"(",CORBA::Python::Cobj_as->NameAttr($self->{symbtab}, $type, 'return'),"_ret, __ret);\n";
			}
	}
	foreach (@{$node->{list_param}}) {	# parameter
			next if ($_->{attr} eq "in");
			my $type = $self->_get_defn($_->{type});
			my $fmt = CORBA::Python::CPy_format->NameAttr($self->{symbtab}, $type);
			if ($fmt eq "O") {
				print $FH "\t\tPYOBJ_CHECK_",$type->{c_name},"(_",$_->{c_name},");\n";
				print $FH "\t\tPYOBJ_AS_",$_->{attr},"_",$type->{c_name},"(",CORBA::Python::Cobj_as->NameAttr($self->{symbtab}, $type, $_->{attr}), $_->{c_name},", _",$_->{c_name},");\n";
			}
	}
	print $FH "\t} else {\n";
	print $FH "\t\t_exc = PyErr_Occurred(); // Borrowed reference\n";
	print $FH "\t\tif (NULL == _exc) {\n";
	if ($self->{assert}) {
		print $FH "\t\t\tassert(0);\n";
	}
	print $FH "\t\t\tCORBA_exception_set_system(_ev, ex_CORBA_INTERNAL, CORBA_COMPLETED_MAYBE);\n";
	print $FH "\t\t} else {\n";
	print $FH "\t\t\tif (PyErr_GivenExceptionMatches(PyExc_AttributeError, _exc)) {\n";
	if ($self->{assert}) {
		print $FH "\t\t\t\tassert(0);\n";
	}
	print $FH "\t\t\t\tCORBA_exception_set_system(_ev, ex_CORBA_NO_IMPLEMENT, CORBA_COMPLETED_NO);\n";
	print $FH "\t\t\t\tgoto err;\n";
	print $FH "\t\t\t} else if (PyErr_GivenExceptionMatches(PyExc_TypeError, _exc)) {\n";
	if ($self->{assert}) {
		print $FH "\t\t\t\tassert(0);\n";
	}
	print $FH "\t\t\t\tCORBA_exception_set_system(_ev, ex_CORBA_BAD_PARAM, CORBA_COMPLETED_NO);\n";
	print $FH "\t\t\t\tgoto err;\n";
	if (exists $node->{list_raise}) {
		foreach (@{$node->{list_raise}}) {
			my $defn = $self->_get_defn($_);
			print $FH "\t\t\t} else if (PyErr_GivenExceptionMatches(_cls_",$defn->{c_name},", _exc)) {\n";
			print $FH "\t\t\t\tPyObject * _type;\n";
			print $FH "\t\t\t\tPyObject * _value;\n";
			print $FH "\t\t\t\tPyObject * _traceback;\n";
			print $FH "#ifdef CORBA_THREADED\n";
			print $FH "\t\t\t\t_",$defn->{c_name}," = ",$defn->{c_name},"__alloc(1);\n";
			if ($self->{assert}) {
				print $FH "\t\t\t\tassert(_",$defn->{c_name}," != NULL);\n";
			}
			print $FH "\t\t\t\tif (_",$defn->{c_name}," == NULL) {\n";
			print $FH "\t\t\t\t\tCORBA_exception_set_system(_ev, ex_CORBA_NO_MEMORY, CORBA_COMPLETED_MAYBE);\n";
			print $FH "\t\t\t\t\tgoto end;\n";
			print $FH "\t\t\t\t}\n";
			print $FH "#endif\n";
			print $FH "\t\t\t\tPyErr_Fetch(&_type, &_value, &_traceback);\n";
			print $FH "\t\t\t\tPYOBJ_AS_",$defn->{c_name},"(*_",$defn->{c_name},", _value);\n";
			print $FH "\t\t\t\tCORBA_exception_set(_ev, CORBA_USER_EXCEPTION, ex_",$defn->{c_name},", _",$defn->{c_name},");\n";
		}
	}
	print $FH "\t\t\t} else {\n";
	print $FH "\t\t\t\tPyErr_Print();\n";
	if ($self->{assert}) {
		print $FH "\t\t\t\tassert(0);\n";
	}
	print $FH "\t\t\t\tCORBA_exception_set_system(_ev, ex_CORBA_INTERNAL, CORBA_COMPLETED_MAYBE);\n";
	print $FH "\t\t\t\tgoto err;\n";
	print $FH "\t\t\t}\n";
	print $FH "\t\t}\n";
	print $FH "\t}\n";
	print $FH "\n";
	print $FH "end:\n";
	if (scalar @fmt_out) {
		print $FH "\tPy_XDECREF(_result);\n";
	}
	print $FH "\tif (NULL != _exc) {\n";
	print $FH "\t\tPyErr_Clear();\n";
	print $FH "\t}\n";
	print $FH "\tif (NULL == _o) {\n";
	print $FH "\t\tPy_XDECREF(_obj);\n";
	print $FH "\t}\n";
	if ($type->isa("VoidType")) {
		print $FH "\treturn;\n";
	} else {
		print $FH "\treturn _ret;\n";
	}
	print $FH "err:\n";
	foreach (@{$node->{list_param}}) {	# parameter
		my $type = $self->_get_defn($_->{type});
		my $fmt = CORBA::Python::CPy_format->NameAttr($self->{symbtab}, $type);
		if (	    $_->{attr} eq 'out'
				and $fmt eq "O"
				and defined $type->{length} ) {
			print $FH "\tFREE_out_",$type->{c_name},"(",CORBA::Python::Cfree_out->NameAttr($self->{symbtab}, $type),$_->{c_name},");\n";
		}
	}
	if (exists $node->{list_raise}) {
		foreach (@{$node->{list_raise}}) {	# exception
			my $defn = $self->_get_defn($_);
			if (defined $defn->{length}) {
				print $FH "\tFREE_",$defn->{c_name},"(*_",$defn->{c_name},");\n";
			}
		}
		print $FH "#ifdef CORBA_THREADED\n";
		foreach (@{$node->{list_raise}}) {	# exception
			my $defn = $self->_get_defn($_);
			print $FH "\tif (_",$defn->{c_name}," != NULL) {\n";
			print $FH "\t\tCORBA_free(_",$defn->{c_name},");\n";
			print $FH "\t}\n";
		}
		print $FH "#endif\n";
	}
	print $FH "\tif (CORBA_NO_EXCEPTION == _ev->_major) {\n";
	print $FH "\t\tCORBA_exception_set_system(_ev, ex_CORBA_MARSHAL, CORBA_COMPLETED_NO);\n";
	print $FH "\t}\n";
	print $FH "\tgoto end;\n";
	print $FH "}\n";
}

#
#	3.14	Attribute Declaration		(inherited)
#

##############################################################################

package CORBA::Python::Cobj_from;

sub NameAttr {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	my $class = ref $type;
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "BaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrBaseInterface : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		if (      $attr eq 'in' ) {
			return "";
		} elsif ( $attr eq 'inout' ) {
			return "";
		} else {
			warn __PACKAGE__,"::NameAttrTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	} else {
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type, $attr);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	warn __PACKAGE__,"::NameAttrNativeType : not supplied \n";
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "*";
	} elsif ( $attr eq 'inout' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "*";
	} elsif ( $attr eq 'inout' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "";
	} elsif ( $attr eq 'inout' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if (      $attr eq 'in' ) {
		return "*";
	} elsif ( $attr eq 'inout' ) {
		return "*";
	} else {
		warn __PACKAGE__,"::NameAttrSequenceType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package CORBA::Python::Cobj_as;

# needs $type->{length}

sub NameAttr {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	my $class = ref $type;
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "BaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if      ( $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrBaseInterface : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		if (      $attr eq 'inout' ) {
			return "";
		} elsif ( $attr eq 'out' ) {
			if (defined $type->{length}) {		# variable
				return "";
			} else {
				return "";
			}
		} elsif ( $attr eq 'return' ) {
			return "";
		} else {
			warn __PACKAGE__,"::NameAttrTypeDeclarator : ERROR_INTERNAL $attr \n";
		}
	} else {
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type, $attr);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	warn __PACKAGE__,"::NameAttrNativeType : not supplied \n";
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if      ( $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} else {
		warn __PACKAGE__,"::NameAttrStructType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrUnionType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if      ( $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} elsif ( $attr eq 'return' ) {
		if (defined $type->{length}) {		# variable
			return "*";
		} else {
			return "";
		}
	} else {
		warn __PACKAGE__,"::NameAttrUnionType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrEnumType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if      ( $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrEnumType : ERROR_INTERNAL $attr \n";
	}
}

sub NameAttrSequenceType {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	if      ( $attr eq 'inout' ) {
		return "";
	} elsif ( $attr eq 'out' ) {
		return "*";
	} elsif ( $attr eq 'return' ) {
		return "";
	} else {
		warn __PACKAGE__,"::NameAttrSequenceType : ERROR_INTERNAL $attr \n";
	}
}

##############################################################################

package CORBA::Python::Cfree_out;

sub NameAttr {
	my $proto = shift;
	my ($symbtab, $type, $attr) = @_;
	my $class = ref $type;
	$class = "BaseInterface" if ($type->isa("BaseInterface"));
	$class = "BaseInterface" if ($type->isa("ForwardBaseInterface"));
	my $func = 'NameAttr' . $class;
	if($proto->can($func)) {
		return $proto->$func($symbtab, $type, $attr);
	} else {
		warn "Please implement a function '$func' in '",__PACKAGE__,"'.\n";
	}
}

sub NameAttrBaseInterface {
	my $proto = shift;
	my ($symbtab, $type) = @_;
	return "*";
}

sub NameAttrTypeDeclarator {
	my $proto = shift;
	my ($symbtab, $type) = @_;
	if (exists $type->{array_size}) {
		warn __PACKAGE__,"::NameAttrTypeDeclarator $type->{idf} : empty array_size.\n"
				unless (@{$type->{array_size}});
		return "";
	} else {
		my $type = $type->{type};
		unless (ref $type) {
			$type = $symbtab->Lookup($type);
		}
		return $proto->NameAttr($symbtab, $type);
	}
}

sub NameAttrNativeType {
	my $proto = shift;
	warn __PACKAGE__,"::NameAttrNativeType : not supplied \n";
}

sub NameAttrAnyType {
	warn __PACKAGE__,"::NameAttrAnyType : not supplied \n";
}

sub NameAttrStructType {
	my $proto = shift;
	my ($symbtab, $type) = @_;
	return "*";
}

sub NameAttrUnionType {
	my $proto = shift;
	my ($symbtab, $type) = @_;
	return "*";
}

sub NameAttrSequenceType {
	my $proto = shift;
	my ($symbtab, $type) = @_;
	return "*";
}

sub NameAttrStringType {
	my $proto = shift;
	my ($symbtab, $type) = @_;
	return "";
}

sub NameAttrWideStringType {
	my $proto = shift;
	my ($symbtab, $type) = @_;
	return "";
}

1;

