--!strict

export type PlayerData = {
	Version: number,
	Coins: number,
	OwnedItems: { [string]: boolean },
	EquippedItems: { [string]: string },
}

export type CatalogItem = {
	Id: string,
	Name: string,
	Slot: string,
	Price: number,
}

export type PlayerState = {
	Coins: number,
	OwnedItems: { [string]: boolean },
	EquippedItems: { [string]: string },
	SavingEnabled: boolean,
}

export type RejectionEntry = {
	Code: string,
	Remote: string,
	ItemId: string?,
}

return {}
