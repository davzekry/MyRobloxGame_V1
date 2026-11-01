--!strict

export type ResultCode =
	"Ok"
	| "NotReady"
	| "RateLimited"
	| "InvalidRequest"
	| "UnknownItem"
	| "AlreadyOwned"
	| "NotEnoughCoins"
	| "NotOwned"
	| "Forbidden"

local ResultCodes = {
	Ok = "Ok" :: ResultCode,
	NotReady = "NotReady" :: ResultCode,
	RateLimited = "RateLimited" :: ResultCode,
	InvalidRequest = "InvalidRequest" :: ResultCode,
	UnknownItem = "UnknownItem" :: ResultCode,
	AlreadyOwned = "AlreadyOwned" :: ResultCode,
	NotEnoughCoins = "NotEnoughCoins" :: ResultCode,
	NotOwned = "NotOwned" :: ResultCode,
	Forbidden = "Forbidden" :: ResultCode,
}

return table.freeze(ResultCodes)
