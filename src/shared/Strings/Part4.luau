--!strict
-- Player-facing strings, part 4 (split: a ModuleScript holds at most 200 000 characters). Add new strings to the last part.

return {
	-- [сеть TG/25] Рынок: Shift + «Купить» — 64 штуки еды
	shop_bulk_hint = {
		ru = "Shift + «Приобрести» — 64 шт.",
		en = "Shift + «Buy» — 64 pcs",
		es = "Shift + «Comprar» — 64 uds.",
		fr = "Maj + « Acheter » — 64 pcs",
	},
	-- [сеть TG/25] блоки из шахт намного выше уровня игрока
	block_locked_sell = {
		ru = "%d блоков из шахт намного выше вашего уровня продать нельзя",
		en = "%d blocks from mines far above your level can't be sold",
		es = "No puedes vender %d bloques de minas muy por encima de tu nivel",
		fr = "%d blocs de mines bien au-dessus de ton niveau ne peuvent pas être vendus",
	},
	block_locked_drop = {
		ru = "Блоки из шахт намного выше вашего уровня нельзя выбросить",
		en = "Blocks from mines far above your level can't be dropped",
		es = "No puedes tirar bloques de minas muy por encima de tu nivel",
		fr = "Impossible de jeter des blocs de mines bien au-dessus de ton niveau",
	},
}
