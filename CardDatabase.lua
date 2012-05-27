
module ( "CardDatabase", package.seeall )

local CardDatabase = { }
CardDatabase["Minion"] =
{
	artName = "CardImages/Memnite.jpg",
	resourceAmount = 1,
	resourceCost = 1,
	power = 2,
	toughness = 3
}

CardDatabase["Bear"] =
{
	artName = "CardImages/GrizzlyBears.jpg",
	resourceAmount = -1,
	resourceCost = 2,
	power = 2,
	toughness = 2
}

CardDatabase["Giant"] =
{
	artName = "CardImages/HillGiant.jpg",
	resourceAmount = 1,
	resourceCost = 3,
	power = 3,
	toughness = 3
}

CardDatabase["Fighter"] =
{
	artName = "CardImages/SadisticAugermage.jpg",
	resourceAmount = 1,
	resourceCost = 2,
	power = 3,
	toughness = 1
}

CardDatabase["Turtle"] =
{
	artName = "CardImages/HornedTurtle.jpg",
	resourceAmount = 1,
	resourceCost = 3,
	power = 1,
	toughness = 4
}

CardDatabase["Warhorse"] =
{
	artName = "CardImages/ArmoredWarhorse.jpg",
	resourceAmount = 1,
	power = 2,
	toughness = 2
}


local CardArtDatabase = { }

function GetCard( cardName )
	return CardDatabase[ cardName ]
end


-- get the MOAIGfxQuad2D for a particular card
-- if we haven't loaded it yet, it will be loaded
function GetCardArt( artName )
	
	cardArtDBentry = CardArtDatabase[ artName ]
	if ( cardArtDBentry == nil ) then
		print("Art for card: " .. artName .. " is not loaded!  Loading now!")
		
		local cardArt = MOAIGfxQuad2D.new()
		cardArt:setTexture ( artName )
		cardArt:setRect( -45, -64, 45, 64 )
		
		CardArtDatabase[ artName ] = cardArt
		return CardArtDatabase[ artName ]
	end
	
	return cardArtDBentry	
end


function CreateCard( cardName )
	
	cardDBentry = CardDatabase[cardName]
	if (cardDBentry == nil ) then
		print( "INVALID database entry for cardName: " .. cardName )
		return nil
	end
	
	local card = { }
	card.artName = cardDBentry.artName
	card.resourceAmount = cardDBentry.resourceAmount
	card.resourceCost = cardDBentry.resourceCost
	card.power = cardDBentry.power
	card.toughness = cardDBentry.toughness
		
	return card
end