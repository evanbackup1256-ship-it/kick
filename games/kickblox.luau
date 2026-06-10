local RS = game:GetService("ReplicatedStorage")

local TrueFallbackBrainrots = {
	"Any",
	"1x1x1x1",
	"67",
	"Agarrini La Palini",
	"Alessio",
	"Anpali Babel",
	"Astro Tim",
	"Astral",
	"Baba Yaga",
	"Ballerina Cappuccina",
	"Bambini Crostini",
	"Bambu Sahur",
	"Bananita Dolphinita",
	"Bangello",
	"Beluga Beluga",
	"Blackhole Goat",
	"Bobrito Bandito",
	"Bombardiro Crocodilo",
	"Bombini Gusini",
	"Boneca Ambalabu",
	"Bottellini",
	"Brr Brr Patapim",
	"Burbaloni Luliloli",
	"Burguro",
	"Cacto Hipopotamo",
	"Cactus Pingu",
	"Capi Taco",
	"Capybara Eggplant",
	"Cappuccino Assassino",
	"Cappuccino Clownino",
	"Castlino Fortini",
	"Cavallo Virtuso",
	"Chef Crabracadabra",
	"Chicleteira Bicicleteira",
	"Chillin Chilli",
	"Chimpanzini Bananini",
	"Cocofanto Elefanto",
	"Compactoroni Diskaloni",
	"Corn Sahur",
	"Crazylone Pizaione",
	"Dipperi Chiperini",
	"Dragon Cannelloni",
	"Dragonfrutina Dolphinita",
	"Elefanto Frigo",
	"Elefantucci Bananucci",
	"Esok Sekolah",
	"Espresso Signora",
	"Frigo Camelo",
	"Fruli Frula",
	"Fryuro",
	"Garamararam",
	"Gangster Footera",
	"Gattatino Nyanino",
	"Girafa Celeste",
	"Glorbo Fruttodrillo",
	"Gorillo Watermelondrillo",
	"Guerriro Digitale",
	"Guest666",
	"John Pork",
	"Karkerkar Kurkur",
	"Ketupat Kepat",
	"Ketchuru Matsuru",
	"Kicky",
	"Krupuk Pagi Pagi",
	"La Vacca Saturno Saturnita",
	"Lirili Larila",
	"Los Nooo My Hotspotsitos",
	"Los Primos",
	"Los Primos Blue",
	"Madung",
	"Mangolini Parrocini",
	"Mastodontico Telepiedone",
	"Matteo",
	"Meowl",
	"Noobini Pizzanini",
	"Nuclearo Dinossauro",
	"Octopusini Bluberini",
	"Orcalero",
	"Orangutini Ananasini",
	"Pandaccini Bananini",
	"Pannaburro",
	"Peant Jarro",
	"Penguino Cocosino",
	"Pesto Mortioni",
	"Pipi Kiwi",
	"Plan Blue",
	"Plan Red",
	"Pot Hotspot",
	"Professora 67",
	"Rexosaurus",
	"Rhino Toasterino",
	"Rinooccio Verdini",
	"Rocky",
	"Salamino Pinguino",
	"Sigma Boy",
	"Spaghetti Tualetti",
	"Stoppo Luminino",
	"Strawberelli Flamingelli",
	"Strawberry Elephant",
	"Svinina Bombardino",
	"SWAG SODA",
	"Ta Ta Ta Ta Sahur",
	"Talpa Di Fero",
	"Tictac Sahur",
	"Tim Cheese",
	"Torrtuginni Dragonfrutini",
	"Tralaledon",
	"Tralalero Tralala",
	"Tralalerita Tralala",
	"Tripi Tropi Tropa Tripa",
	"Trippi Troppi",
	"Trulimero Trulicina",
	"Tuff Toucan",
	"Udin Din Din Dun",
	"W",
	"W or L",
	"Waterdino",
	"Zibra Zubra Zibralini"
}

local GameData = {
	RarityMap = {},
	BrainrotOptions = TrueFallbackBrainrots,
	RarityOptions = {
		"Any",
		"Common",
		"Rare",
		"Epic",
		"Legendary",
		"Mythic",
		"Godly",
		"Secret",
		"Divine",
		"Hacked",
		"OG",
		"Celestial",
		"Exclusive",
		"Eternal"
	},
	MutationOptions = {
		"Any",
		"None",
		"Golden",
		"Diamond",
		"Plasma",
		"Molten",
		"Radioactive",
		"Void",
		"Shadow",
		"Electrified",
		"Rainbow",
		"Virus",
		"Wet",
		"Alien",
		"Bacon",
		"Enchanted",
		"Phantom",
		"Astral",
		"Volcanic"
	}
}

local sharedFolder = RS:WaitForChild("Shared", 8)
local dataFolder = sharedFolder and sharedFolder:WaitForChild("Data", 5)
local entitiesModule = dataFolder and dataFolder:WaitForChild("EntitiesData", 5)

if entitiesModule then
	local success, EntitiesData = pcall(function()
		return require(entitiesModule)
	end)
	
	if success and EntitiesData and EntitiesData.Brainrots then
		GameData.BrainrotOptions = { "Any" }
		
		for brName, brData in pairs(EntitiesData.Brainrots) do
			if brData.Rarity then
				GameData.RarityMap[brName] = brData.Rarity
			end
			table.insert(GameData.BrainrotOptions, brName)
		end
		
		table.sort(GameData.BrainrotOptions, function(a, b)
			if a == "Any" then
				return true
			end
			if b == "Any" then
				return false
			end
			return a < b
		end)
	end
end

return GameData
