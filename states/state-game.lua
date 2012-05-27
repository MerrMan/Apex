--==============================================================
-- Copyright (c) 2010-2012 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
--==============================================================

require "CardDatabase"

local HAND_LOCATION_START_X 		= -220
local HAND_DISTANCE_BETWEEN_CARDS 	= 100
local HAND_LOCATION_START_Y 		= -280
local HAND_SIZE						= 5

local PLAYER_DECK_LOCATION_X		= -380
local PLAYER_DECK_LOCATION_Y		= -280
local PLAYER_DECK_ART_PATH			= "resources/DeckZone.jpg"

local DISCARD_LOCATION_X			= 380
local DISCARD_LOCATION_Y			= -280
local DISCARD_ART_PATH				= "resources/DiscardZone.jpg"

local NUM_CAPTURE_ZONES				= 3

local game = {}
game.layerTable = nil

local mainLayer = nil
local card = nil
local textboxClicks = nil
local textboxClock = nil
local processing = false

local grabbedCard = nil
local grabOffsetX = 0
local grabOffsetY = 0

local globalDeck = { }
local playerDeck = { }
local hand = { }
local discard = { }
local deploymentZone = { }
local captureZones = { }
for i=1, NUM_CAPTURE_ZONES do
	table.insert( captureZones, {} )
end

-- helper function to find the time until the user can click
game.getTimeLeft = function ()
	local _time
	if processing then
		_time = 60
	else
		_time = globalData.timeToClick - os.difftime ( os.time(), globalData.currentTime ) 
		if _time < 0 then
			_time = 0
		end
	end
	return _time
end

----------------------------------------------------------------
game.ClickCloud = function ()

	local task
	local result
	local code
	
	--get the user id for further cloud queries
	local saveFile = savefiles.get ( "user" )
	local userId = saveFile.data.id
	
	--update with new click
	task = cloud.createPostTask ( "user/"..userId, { click=true} )
	result,code = task:waitFinish()
	
	if result then
		globalData.currentTime = os.time ()
		globalData.timeToClick = result.timeToClick
		globalData.clicks = result.clicks
	else
		print ( "failed to get user , code" .. code  )
	end 
	
	processing = false
	
end

----------------------------------------------------------------
game.CardGrab = function( self )
	print( 'CardGrab!' )
	cardGrabbed = not cardGrabbed
	
	local x,y = mainLayer:wndToWorld ( inputmgr:getTouch ())
	local propLocX, propLocY = card.img:getLoc()
	grabOffsetX = propLocX - x
	grabOffsetY = propLocY - y
end
----------------------------------------------------------------
game.onFocus = function ( self )
	
	MOAIGfxDevice.setClearColor ( 0, 0, 0, 1 )
end	

----------------------------------------------------------------
game.onInput = function ( self )

	-- lock input if client side time check is failing
	if ( self.getTimeLeft () <= 0 ) then
	
		if inputmgr:down() then
			-- check for a grabbed card
			local x, y = mainLayer:wndToWorld ( inputmgr:getTouch () )
			for k, v in ipairs(hand) do
				if v.prop:inside(x,y,0) then
					
					grabbedCard = v

					local propLocX, propLocY = grabbedCard.prop:getLoc()
					grabOffsetX = propLocX - x
					grabOffsetY = propLocY - y
				end
			end
		elseif inputmgr:up() then
			
			-- release the card
			if grabbedCard then
				
				discarded = false
				-- check for Discard release
				local x, y = mainLayer:wndToWorld ( inputmgr:getTouch () )
				if discardProp:inside(x,y,0) then
					-- can this card be discarded for resources?
					if grabbedCard.resourceAmount > -1 then
						table.insert(discard, grabbedCard)
						local cardIndex = GetCardIndexInHand( grabbedCard )						
						table.remove(hand, cardIndex)
						ArrangeHand()
						discarded = true
					end
				end

				if not discarded then
					ReturnCardToHandLoc( grabbedCard )
				end
			end
			
			grabbedCard = nil
			grabOffsetX = 0
			grabOffsetY = 0
		end

		--[[	
		-- send input to the card button
		if inputmgr:up () then
			local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
			card:updateClick ( false, x, y )
			
		elseif inputmgr:down () then
			local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
			card:updateClick ( true, x, y )
		end
		]]--
	end
	
	if grabbedCard then
		local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
		print( x .. ', ' .. y )
		grabbedCard.prop:setLoc( x + grabOffsetX, y + grabOffsetY )
	end
end

---------------------------------------------------
function GetCardIndexInHand( card )
	local cardIndex = 0
	for k, v in ipairs(hand) do
		if v == card then
			return k
		end
	end
	
	print("CARD CANNOT BE FOUND IN THE HAND")
	return cardIndex
end

--------------------------------------------------
function ReturnCardToHandLoc( card )
	local cardIndex = GetCardIndexInHand( card )
	
	local destX, destY = GetCardHandLoc(cardIndex)
	print( "Releasing Card - Card index: " .. cardIndex .. ", x = " .. destX .. ", y = " .. destY )

	card.prop:seekLoc(destX, destY, 1, MOAIEaseType.EASE_IN)
end


----------------------------------------------------------------
game.onLoad = function ( self )

	self.layerTable = {}
	local layer = MOAILayer2D.new ()
	layer:setViewport ( viewport )
	game.layerTable [ 1 ] = { layer }
	
	local font =  MOAIFont.new ()
	font:loadFromTTF ( "arialbd.ttf", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.?! ", 12, 163 )
	
	textboxClicks = MOAITextBox.new ()
	textboxClicks:setFont ( font )
	textboxClicks:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	textboxClicks:setYFlip ( true )
	textboxClicks:setRect ( -150, -230, 150, 230 )
	textboxClicks:setString ( "Clicks - " .. globalData.clicks )
	layer:insertProp ( textboxClicks )
	
	textboxClock = MOAITextBox.new ()
	textboxClock:setFont ( font )
	textboxClock:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	textboxClock:setYFlip ( true )
	textboxClock:setRect ( -150, -230, 150, 230 )
	textboxClock:setLoc ( 0, -100 )
	textboxClock:setString ( "Time to next click - " .. self.getTimeLeft () )
	layer:insertProp ( textboxClock )

	--card = elements.makeButton( "CardTest.jpg", 90, 128 )
	--card:setCallback( function ( self )
	--	local thread = MOAIThread.new()
	--	thread:run( game.CardGrab )
	--end )
	--layer:insertProp ( card.img )
	
	mainLayer = layer
	
	InitializeDiscardZone()
	InitializePlayerDeckZone()

	-- create the global deck
	for i=1, 10 do local card = CardDatabase.CreateCard("Giant") table.insert(globalDeck, card) end
	for i=1, 10 do local card = CardDatabase.CreateCard("Fighter") table.insert(globalDeck, card) end
	for i=1, 10 do local card = CardDatabase.CreateCard("Turtle") table.insert(globalDeck, card) end
	for i=1, 10 do local card = CardDatabase.CreateCard("Warhorse") table.insert(globalDeck, card) end
	ShuffleDeck(globalDeck)
	
	-- create the player deck
	for i=1, 8 do local card = CardDatabase.CreateCard("Minion") table.insert(playerDeck, card) end
	for i=1, 2 do local card = CardDatabase.CreateCard("Bear") table.insert(playerDeck, card) end
	ShuffleDeck(playerDeck)
	
	-- draw the opening hand cards to start the turn!
	for i=1, HAND_SIZE do
		DrawCard( playerDeck, hand )
	end
	
	ArrangeHand()
end


----------------------------------------------
function InitializeDiscardZone()
	local discardArt = MOAIGfxQuad2D.new()
	discardArt:setTexture ( DISCARD_ART_PATH )
	discardArt:setRect( -45, -64, 45, 64 )
	
	discardProp = MOAIProp2D.new()
	discardProp:setDeck( discardArt )
	discardProp:setLoc( DISCARD_LOCATION_X, DISCARD_LOCATION_Y )
	
	mainLayer:insertProp( discardProp )
end

----------------------------------------------
function InitializePlayerDeckZone()
	local playerDeckArt = MOAIGfxQuad2D.new()
	playerDeckArt:setTexture ( PLAYER_DECK_ART_PATH )
	playerDeckArt:setRect( -45, -64, 45, 64 )
	
	playerDeckProp = MOAIProp2D.new()
	playerDeckProp:setDeck( playerDeckArt )
	playerDeckProp:setLoc( PLAYER_DECK_LOCATION_X, PLAYER_DECK_LOCATION_Y )
	
	mainLayer:insertProp( playerDeckProp )
end

function DrawCard( FromDeck, ToHand )
	local cardToDraw = FromDeck[1]
	table.insert( ToHand, cardToDraw )
	table.remove( FromDeck, 1 )
	
	-- when we draw the card, we want to create the visual element to go along with it
	-- this will be destroyed when the card is discarded from play
	cardToDraw.prop = MOAIProp2D.new()
	if ( cardToDraw.artName == nil ) then
		print( "IVALID art name for card!" )
	else
		print( "Going to get the art for :" .. cardToDraw.artName )
	end
	local cardGfx = CardDatabase.GetCardArt( cardToDraw.artName )
	cardToDraw.prop:setDeck( cardGfx )
	cardToDraw.prop:setLoc( PLAYER_DECK_LOCATION_X, PLAYER_DECK_LOCATION_Y )
	
	mainLayer:insertProp( cardToDraw.prop )
end


function DiscardCard( FromHand )
	if card.CanBeDiscarded() then
	end
end

-------------------------------------------------------------
function ShuffleDeck( deck )
	local n = #deck
	while n >= 1 do
		local k = math.random(n)
		if k ~= n then
			deck[n], deck[k] = deck[k], deck[n]
		end
		n = n - 1
	end
end

------------------------------------------------------------
function GetCardHandLoc( cardIndex )
	local numCards = #hand
	local x = (cardIndex - ((numCards+1)/2)) * HAND_DISTANCE_BETWEEN_CARDS	
	local y = HAND_LOCATION_START_Y
	return x,y
end

function ArrangeHand( )
	for k,v in ipairs(hand) do
		--local x,y = GetCardHandLoc(k)
		--v.prop:setLoc(x, y)
		ReturnCardToHandLoc(v)
	end
end

----------------------------------------------------------------
game.onUnload = function ( self )
	
	for i, layerSet in ipairs ( self.layerTable ) do
		
		for j, layer in ipairs ( layerSet ) do
		
			layer = nil
		end
	end
	
	self.layerTable = nil
	mainLayer = nil
end

----------------------------------------------------------------
game.onUpdate = function ( self )
	
	textboxClicks:setString ( "Clicks - " .. globalData.clicks )
	textboxClock:setString ( "Time to next click - " .. self.getTimeLeft () )
end

return game