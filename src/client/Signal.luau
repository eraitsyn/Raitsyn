--!strict
-- A minimal signal: connect, fire, disconnect. Each handler runs in its own
-- thread (started immediately, in connect order), so an error in one is
-- reported and does not stop the others.

export type Connection = { Disconnect: (self: Connection) -> () }

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { (T...) -> () } = {}
	local signal = {}

	function signal.Connect(_self, fn: (T...) -> ()): Connection
		table.insert(handlers, fn)
		local connection = {}
		function connection.Disconnect(_conn)
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end
		return connection :: any
	end

	function signal.Fire(_self, ...: T...)
		for _, fn in table.clone(handlers) do
			task.spawn(fn, ...)
		end
	end

	return signal :: any
end

return Signal
