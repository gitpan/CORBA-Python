
import PyIDL as CORBA
import PyIDL.cdr as CDR
import PyIDL.iop as IOP
import PyIDL.giop as GIOP

_request_id = 0

def _getRequestId():
	global _request_id
	_request_id += 1
	return _request_id

def RequestOneWay(sock, request_header, request_body):
	request_header.request_id = _getRequestId()
	request = CDR.OutputBuffer()
	request_header.marshal(request)
	request.write(request_body.getvalue())
	msg = CDR.OutputBuffer()
	GIOP.MessageHeader_1_1(
			magic="GIOP",
			GIOP_version=GIOP.Version(major=1, minor=2),
			flags=0x01,	# flags : little endian
			message_type=0,		# Request
			message_size=len(request.getvalue())
	).marshal(msg)
	msg.write(request.getvalue())
	request.close()
	sock.send(msg.getvalue())
	msg.close()

def RequestReply(sock, request_header, request_body):
	request_header.request_id = _getRequestId()
	request = CDR.OutputBuffer()
	request_header.marshal(request)
	request.write(request_body.getvalue())
	msg = CDR.OutputBuffer()
	GIOP.MessageHeader_1_1(
			magic="GIOP",
			GIOP_version=GIOP.Version(major=1, minor=2),
			flags=0x01,	# flags : little endian
			message_type=0,		# Request
			message_size=len(request.getvalue())
	).marshal(msg)
	msg.write(request.getvalue())
	request.close()
	sock.send(msg.getvalue())
	msg.close()
	while True :
		_header = sock.recv(12)
		header = CDR.InputBuffer(_header)
		magic = ''
		magic += CORBA.demarshal(header, 'char')
		magic += CORBA.demarshal(header, 'char')
		magic += CORBA.demarshal(header, 'char')
		magic += CORBA.demarshal(header, 'char')
		GIOP_version = GIOP.Version.demarshal(header)
		flags = CORBA.demarshal(header, 'octet')
		endian = flags & 0x01
		header.endian = endian			# now, endian is known
		message_type = CORBA.demarshal(header, 'octet')
		message_size = CORBA.demarshal(header, 'unsigned_long')

		if magic == 'GIOP' and GIOP_version.major == 1 and GIOP_version.minor == 2 and message_type == 1 :
			_reply = ''
			while (message_size > 0) :
				reply_i = sock.recv(message_size)
				_reply += reply_i
				message_size -= len(reply_i)
			reply = CDR.InputBuffer(_reply, endian)
			reply_header = GIOP.ReplyHeader_1_2.demarshal(reply)
			if request_header.request_id == reply_header.request_id :
#				print "reply id %d" % reply_header.request_id
				return (reply_header.reply_status, reply_header.service_context, reply)
			elif request_id > reply_header.request_id :
				print "bad request id %d (waiting %d).\n" % (reply_header.request_id, request_header.request_id)
#				goto RETRY
			else :
				print "bad request id %d (waiting %d).\n" % (reply_header.request_id, request_header.request_id)
				raise CORBA.SystemException("IDL:CORBA/INTERNAL:1.0", 8, CORBA.CORBA_COMPLETED_MAYBE)
		else :
			print "bad header."
			raise CORBA.SystemException("IDL:CORBA/INTERNAL:1.0", 8, CORBA.CORBA_COMPLETED_MAYBE)

class Servant(object):
	def __init__(self):
		self.itf = dict()

	def Register(self, key, value):
		self.itf[key] = value

	def Servant(self, request):
		message = CDR.InputBuffer(request)
		magic = ''
		magic += CORBA.demarshal(message, 'char')
		magic += CORBA.demarshal(message, 'char')
		magic += CORBA.demarshal(message, 'char')
		magic += CORBA.demarshal(message, 'char')
		GIOP_version = GIOP.Version.demarshal(message)
		flags = CORBA.demarshal(message, 'octet')
		endian = flags & 0x01
		message.endian = endian			# now, endian is known
		message_type = CORBA.demarshal(message, 'octet')
		message_size = CORBA.demarshal(message, 'unsigned_long')
		if magic == 'GIOP' and GIOP_version.major == 1 and GIOP_version.minor == 2 and message_type == 0 :
			request_header = GIOP.RequestHeader_1_2.demarshal(message)
			interface = request_header.target._v
			if self.itf.has_key(interface) == False :
				print "unknown interface '%s'." % interface
				reply_status = GIOP.SYSTEM_EXCEPTION
				reply_body = CDR.OutputBuffer()
				CORBA.marshal(reply_body, 'string', 'IDL:CORBA/NO_IMPLEMENT:1.0')
				CORBA.marshal(reply_body, 'unsigned_long', 11)
				CORBA.marshal(reply_body, 'unsigned_long', 1)	# COMPLETED_NO
			else :
				classname = self.itf[interface]
				op = request_header.operation
				if hasattr(classname, op) == False :
					print "unknown operation '%s'." % op
					reply_status = GIOP.SYSTEM_EXCEPTION
					reply_body = CDR.OutputBuffer()
					CORBA.marshal(reply_body, 'string', 'IDL:CORBA/BAD_OPERATION:1.0')
					CORBA.marshal(reply_body, 'unsigned_long', 13)
					CORBA.marshal(reply_body, 'unsigned_long', 1)	# COMPLETED_NO
				else :
					srv_op = '_skel_' + op
					(reply_status, reply_body) = getattr(classname, srv_op)(message)
					if reply_status == None :
						return (None, message.read())		# oneway
			reply = CDR.OutputBuffer()
			GIOP.ReplyHeader_1_2(
				request_id=request_header.request_id,
				reply_status=reply_status,
				service_context=IOP.ServiceContextList([])
			).marshal(reply)
			reply.write(reply_body.getvalue())
			reply_body.close()
			buffer = CDR.OutputBuffer()
			GIOP.MessageHeader_1_1(
				magic="GIOP",
				GIOP_version=GIOP.Version(major=1, minor=2),
				flags=0x01,			# flags : little endian
				message_type=1,		# Reply
				message_size=len(reply.getvalue())
			).marshal(buffer)
			buffer.write(reply.getvalue())
			reply.close()
			s = buffer.getvalue()
			buffer.close()
			return (s, message.read())

