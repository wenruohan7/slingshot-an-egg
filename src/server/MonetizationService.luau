--!strict
-- Robux purchases from the Shop button: game passes (owned forever) and
-- developer products (coin packs, bought any number of times). Items are set up
-- in Config.RobuxShop. The client opens Roblox's purchase window; this service
-- checks what each player owns and hands out what they bought.
--
-- Owned passes become player attributes ("Pass_VIP", "Pass_Luck2x", ...), which
-- DataService.income and HatchService read for their bonuses.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Config = require(Shared.Config)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)

local MonetizationService = {}

local MIN_PACK_COINS = 100 -- a coin pack is never smaller than this, even with no pets yet

local function grantPass(player: Player, key: string)
	if player:GetAttribute("Pass_" .. key) == true then
		return
	end
	player:SetAttribute("Pass_" .. key, true)
	-- VIP changes income, so refresh the numbers and the plot sign.
	EconomyService.publish(player)
	PlotService.refresh(player)
end

local function checkPasses(player: Player)
	for _, pass in Config.RobuxShop.Passes do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				grantPass(player, pass.Key)
			end
		end
	end
end

local function onPassPurchased(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return
	end
	for _, pass in Config.RobuxShop.Passes do
		if pass.Id == passId then
			grantPass(player, pass.Key)
			EconomyService.notify(player, `Thanks! You got {pass.Name}!`, "good")
		end
	end
end

-- Called by Roblox for every developer product bought. Returning
-- NotProcessedYet makes Roblox try again later (e.g. data not loaded yet).
local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.get(player)
	if not (player and data) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	for _, product in Config.RobuxShop.Products do
		if product.Id ~= 0 and product.Id == receipt.ProductId then
			local coins = math.max(DataService.income(data, player) * product.IncomeSeconds, MIN_PACK_COINS)
			data.Coins += coins
			EconomyService.publish(player)
			DataService.saveNow(player)
			EconomyService.notify(player, `Thanks! +{Format.coins(coins)} coins`, "good")
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	warn(`Unknown developer product {receipt.ProductId}; add it to Config.RobuxShop.Products.`)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.init()
	Players.PlayerAdded:Connect(checkPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchased)
	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
