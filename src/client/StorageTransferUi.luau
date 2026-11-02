--!strict
-- A shared chest request is acknowledged only by the durable profile revision and an idle server.
local StorageTransferUi = {}
export type Pending = { settled: number, page: number }
export type State = { pending: Pending?, queue: { page: number, index: number }? }

function StorageTransferUi.new(): State
	return { pending = nil, queue = nil }
end

function StorageTransferUi.begin(state: State, settled: number, page: number): Pending
	local token = { settled = settled, page = page }
	state.pending = token
	return token
end

function StorageTransferUi.observe(state: State, settled: number, serverBusy: boolean, page: number)
	if state.queue and state.queue.page ~= page then
		state.queue = nil
	end
	local pending = state.pending
	if pending and pending.page ~= page then
		state.pending, state.queue = nil, nil
	elseif pending and settled > pending.settled and not serverBusy then
		state.pending = nil
	end
end

function StorageTransferUi.expire(state: State, token: Pending): boolean
	if state.pending ~= token then
		return false
	end
	state.pending, state.queue = nil, nil
	return true
end

function StorageTransferUi.next(state: State): number?
	local queue = state.queue
	if state.pending or not queue then
		return nil
	end
	if queue.index > 27 then
		state.queue = nil
		return nil
	end
	local index = queue.index
	queue.index += 1
	return index
end

return StorageTransferUi
