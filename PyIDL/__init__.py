
_itf_embedded = dict()

def Register(key, value):
	"""Register an embedded class"""
	_itf_embedded[key] = value

def Lookup(key):
	"""Lookup an embedded class"""
	return _itf_embedded.get(key, None)



def marshal(output, name, value):
	func = name + '__marshal'
	getattr(output, func)(value)

def demarshal(input, name):
	func = name + '__demarshal'
	return getattr(input, func)()

def check(type, value):
	if isinstance(type, str) :
		if type == 'char' :
			if len(value) != 1 :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'wchar' :
			if len(value) != 1 :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'octet' :
			if value < 0 or value > 255 :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'short' :
			if value < -32768 or value > 32767 :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'unsigned_short' :
			if value < 0 or value > 65535 :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'long' :
			if value < -2147483648 or value > 2147483647 :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'unsigned_long' :
			if value < 0 or value > 4294967295L :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'long_long' :
			if value < -9223372036854775808L or value > 9223372036854775807L :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'unsigned_long_long' :
			if value < 0 or value > 18446744073709551615L :
				raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)
		elif type == 'float' :
			pass
		elif type == 'double' :
			pass
		elif type == 'long_double' :
			pass
		elif type == 'boolean' :
			pass
		elif type == 'string' :
			pass
		elif type == 'wstring' :
			pass
		else :
			raise "Internal Error : %s" % type
	else :
		if isinstance(value, type) == False :
			raise SystemException("IDL:CORBA/BAD_PARAM:1.0", 2, CORBA_COMPLETED_MAYBE)

class UserException(Exception):
	"""An IDL exception is translated into a Python class derived from CORBA.UserException."""
	pass

class SystemException(Exception):      
	"""CORBA.SystemException"""

	def __init__(self, repos_id, minor, completed):
		self.repos_id = repos_id
		self.minor = minor
		self.completed = completed

	def __str__(self):
		return self.repos_id

CORBA_COMPLETED_YES = 0    # The object implementation has completed
                           # processing prior to the exception being raised.
CORBA_COMPLETED_NO = 1     # The object implementation was never initiated
                           # prior to the exception being raised.
CORBA_COMPLETED_MAYBE = 2  # The status of implementation completion is
                           # indeterminate.

class Enum(object):
	"""base class for IDL enum"""

	def __init__(self, str, val):
		self._val = val
		self._enum_str[val] = str
		self._enum[val] = self

	def marshal(self, output):
		output.long__marshal(self._val)

	def demarshal(cls, input):
		val = input.long__demarshal()
		if cls._enum.has_key(val) :
			return cls._enum[val]
		else :
			raise 'CORBA.MARSHAL'
	demarshal = classmethod(demarshal)

	def __repr__(self):
		return self._enum_str[self._val]

