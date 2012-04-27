require 'json'
require 'socket'
require 'base64'
require 'openssl'
require 'net/http'

JSON_RPC_VERSION = '2.0'

module Jr
	class Error < Exception
		@@message = 'There was an error communicating with the JSON RPC server.'

		# @jr is the instance of JR that raised the exception.
		attr_reader :jr

		def initialize(jr, msg=@@message)
			@jr = jr

			super(msg)
		end
	end

	class AuthenticationError < Error
		@@message = 'There was an error authenticating to the JSON RPC server.'
	end

	class IDMismatch < Error
		@@message = 'The server sent us a response with an unexpected id.'
	end

	# ProtocolMismatch is raised when value of 'rpcjson' returned by the server
	# does not match JSON_RPC_VERSION. Because of errors in JSON RPC servers, it
	# is *NOT* raised if 'rpcjson' is omitted, even though that is required by the
	# (draft) specification.
	class ProtocolMismatch < Error
		def initialize(jr, version)
			super(jr, "We expected to receive a version '#{JSON_RPC_VERSION}' "\
			          "response, but actually got a #{version.inspect} one.")
		end
	end

	# ReservedMethod is raised if a method beginning with 'rpc' is called.
	class ReservedMethod < Error
		@@message = '%s is a reserved method'

		# @method is the name of the reserved method.
		attr_reader :method

		def initialize(jr, method, msg=@@message)
			@method = method
			super(jr, meth % msg)
		end
	end

	# ServerError is raised when the server requests (via the error property) that
	# an exception be raised in client code.
	class ServerError < Error
		# @code is a Fixnum specifying the type of the error.
		attr_reader :code
		# @message is a String providing a short description of the error.
		attr_reader :message
		# @data is an Object providing additional information about the error.
		attr_reader :data

		def initialize(jr, code, message, data)
			@code, @message, @data = code, message, data

			super(jr, "Error %d: %s" % [code, message])
		end
	end

	# Jr lets you communicate with an HTTP JSON RPC server.
	class Jr
		attr_reader :host, :port, :user, :password, :ssl

		# @connection is a Net::HTTP.
		attr_reader :connection

		def initialize(host, port, user=nil, password=nil, ssl=false)
			%w{host user port password ssl}.each do |var|
				instance_variable_set("@#{var}", eval(var))
			end
		end

		# Call method on the server, and return the result.
		def request(method, *args)
			if method.to_s.start_with?('rpc')
				raise ReservedMethod.new(method)
			end

			reqid = get_request_id()
			data = JSON.dump(
				jsonrpc: '2.0',
				method: method.to_s,
				params: args,
				id: reqid
			)

			r = parse_json_data(http_request(data))
			if r.has_key?('jsonrpc') and (r['jsonrpc'] != JSON_RPC_VERSION)
				# Even though the JSON RPC specification requires that a 'jsonrpc' key
				# is present, we don't require it because not all servers implement it.
				raise ProtocolMismatch.new(self, r['jsonrpc'])
			elsif r['id'] != reqid
				raise IDMismatch.new(self)
			elsif r['error']
				raise ServerError.new(self, r['error']['code'], r['error']['message'],
				                      r['error']['data'])
			end

			r['result']
		end

		def method_missing(meth, *args)
			request(meth, *args)
		end

		private

		# We return the unparsed response of the JSON RPC server to the serialized
		# request data.
		def http_request(data)
			unless @connection
				@connection = Net::HTTP.new(@host, @port)
				@connection.use_ssl = @ssl
			end

			req = Net::HTTP::Post.new('/')
			req.basic_auth(@user, @password)
			req.content_type = 'multipart/form_data'
			req.body = data

			resp = @connection.request(req)
			if Net::HTTPUnauthorized === resp
				raise AuthenticationError.new(self)
			end

			resp.body()
		end

		# Generate a request ID. We use a random string for this.
		def get_request_id()
			@random_instance ||= Random.new
			Base64.urlsafe_encode64(@random_instance.bytes(12))
		end

		# Parse JSON data.
		def parse_json_data(data)
			JSON.parse(data)
		end
	end
end
