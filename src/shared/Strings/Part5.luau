--!strict
-- Player-facing strings, part 5 (split: a ModuleScript holds at most 200 000 characters). Add new strings to the last part.

return {
	-- paid auction announcements (AuctionService, AuctionBanner) [владелец 28.10]
	auction_announce_chat = {
		ru = "[Аукцион] %s выставил «%s» за %s",
		en = "[Auction] %s listed «%s» for %s",
		es = "[Subasta] %s puso «%s» por %s",
		fr = "[Enchères] %s met en vente « %s » pour %s",
	},
	auction_announce_banner = {
		ru = "Аукцион · %s",
		en = "Auction · %s",
		es = "Subasta · %s",
		fr = "Enchères · %s",
	},
	auction_announce_open = {
		ru = "Открыть",
		en = "Open",
		es = "Abrir",
		fr = "Ouvrir",
	},
	auction_announce_no_lot = {
		ru = "Этого лота уже нет на аукционе",
		en = "This lot is no longer on the auction",
		es = "Este lote ya no está en la subasta",
		fr = "Ce lot n'est plus aux enchères",
	},
	auction_announce_busy = {
		ru = "Ваше объявление уже ждёт очереди",
		en = "Your announcement is already waiting in the queue",
		es = "Tu anuncio ya está esperando en la cola",
		fr = "Ton annonce attend déjà dans la file",
	},
	auction_announce_queue_full = {
		ru = "Очередь объявлений сейчас слишком длинная, попробуйте позже (объявлений в запасе: %d)",
		en = "The announcement queue is too long now, try later (announcements in stock: %d)",
		es = "La cola de anuncios es demasiado larga, inténtalo más tarde (anuncios en reserva: %d)",
		fr = "La file des annonces est trop longue, réessaie plus tard (annonces en réserve : %d)",
	},
	auction_announce_now = {
		ru = "Объявление о лоте выходит на всех серверах",
		en = "Your lot is being announced on every server",
		es = "Tu lote se anuncia en todos los servidores",
		fr = "Ton lot est annoncé sur tous les serveurs",
	},
	auction_announce_queued = {
		ru = "Объявление в очереди: выйдет на всех серверах через %d с",
		en = "Announcement queued: it airs on every server in %d s",
		es = "Anuncio en cola: saldrá en todos los servidores en %d s",
		fr = "Annonce en file : diffusée sur tous les serveurs dans %d s",
	},
	auction_announce_refund = {
		ru = "Лот ушёл до объявления — объявление вернулось вам, его можно использовать для другого лота",
		en = "The lot was gone before its announcement — you got the announcement back for another lot",
		es = "El lote se fue antes del anuncio: recuperas el anuncio para otro lote",
		fr = "Le lot est parti avant l'annonce — tu récupères l'annonce pour un autre lot",
	},
	auction_announce_title = {
		ru = "Объявить на всех серверах?",
		en = "Announce on every server?",
		es = "¿Anunciar en todos los servidores?",
		fr = "Annoncer sur tous les serveurs ?",
	},
	auction_announce_text = {
		ru = "Все игроки на всех серверах увидят ваш лот: предмет, зачарования, количество, цену и ваш ник.",
		en = "Every player on every server sees your lot: the item, its enchantments, the amount, the price and your name.",
		es = "Todos los jugadores de todos los servidores verán tu lote: objeto, encantamientos, cantidad, precio y tu nombre.",
		fr = "Tous les joueurs de tous les serveurs verront ton lot : l'objet, ses enchantements, la quantité, le prix et ton pseudo.",
	},
	auction_announce_wait = {
		ru = "Выйдет через ~%s",
		en = "Airs in ~%s",
		es = "Sale en ~%s",
		fr = "Diffusion dans ~%s",
	},
	auction_announce_wait_now = {
		ru = "Выйдет сразу",
		en = "Airs right away",
		es = "Sale de inmediato",
		fr = "Diffusion immédiate",
	},
	auction_announce_full = {
		ru = "Очередь слишком длинная — попробуйте позже",
		en = "The queue is too long — try later",
		es = "La cola es demasiado larga: inténtalo más tarde",
		fr = "La file est trop longue — réessaie plus tard",
	},
	auction_announce_free = {
		ru = "Объявить (в запасе: %d)",
		en = "Announce (in stock: %d)",
		es = "Anunciar (en reserva: %d)",
		fr = "Annoncer (en réserve : %d)",
	},
	auction_announce_robux = {
		ru = "За %d R$",
		en = "For %d R$",
		es = "Por %d R$",
		fr = "Pour %d R$",
	},
	auction_announce_crystals = {
		ru = "За %d кристаллов",
		en = "For %d crystals",
		es = "Por %d cristales",
		fr = "Pour %d cristaux",
	},
	auction_announce_no = {
		ru = "Не нужно",
		en = "No thanks",
		es = "No, gracias",
		fr = "Non merci",
	},
	donate_announce_name = {
		ru = "Объявление на аукционе",
		en = "Auction announcement",
		es = "Anuncio de subasta",
		fr = "Annonce aux enchères",
	},
	donate_desc_announce = {
		ru = "Ваш лот увидят все игроки на всех серверах: баннер сверху и строка в чате.",
		en = "Every player on every server sees your lot: a banner at the top and a chat line.",
		es = "Todos los jugadores de todos los servidores verán tu lote: un cartel arriba y una línea en el chat.",
		fr = "Tous les joueurs de tous les serveurs voient ton lot : une bannière en haut et une ligne dans le chat.",
	},
	settings_auction_ads = {
		ru = "Объявления аукциона",
		en = "Auction announcements",
		es = "Anuncios de subasta",
		fr = "Annonces des enchères",
	},
	settings_auction_ads_hint = {
		ru = "Баннеры и строки чата о лотах других игроков",
		en = "Banners and chat lines about other players' lots",
		es = "Carteles y líneas de chat sobre lotes de otros jugadores",
		fr = "Bannières et lignes de chat sur les lots des autres joueurs",
	},
}
