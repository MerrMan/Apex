--==============================================================
-- Copyright (c) 2010-2012 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
--==============================================================

require "CardDatabase"

local HAND_DISTANCE_BETWEEN_CARDS 			= 100
local HAND_LOCATION_START_Y 				= -280
local HAND_SIZE								= 5

local PLAYER_DECK_LOCATION_X				= -380
local PLAYER_DECK_LOCATION_Y				= -280
local PLAYER_DECK_ART_PATH					= "resources/DeckZone.jpg"

local GLOBAL_DECK_LOCATION_X				= -380
local GLOBAL_DECK_LOCATION_Y				= 120
local GLOBAL_DECK_ART_PATH					= "resources/GlobalDeckZone.jpg"

local DISCARD_LOCATION_X					= 380
local DISCARD_LOCATION_Y					= -280
local DISCARD_ART_PATH						= "resources/DiscardZone.jpg"

local END_TURN_BUTTON_WIDTH					= 150
local END_TURN_BUTTON_HEIGHT				= 75
local END_TURN_BUTTON_TEXT_Y				= 20
local END_TURN_BUTTON_X						= 380
local END_TURN_BUTTON_Y						= -150

local NUM_CAPTURE_CARDS						= 3

local CAPTURE_CARD_DISTANCE_BETWEEN_CARDS	= 150
local CAPTURE_CARD_LOC_Y					= GLOBAL_DECK_LOCATION_Y

local DEPLOY_ZONE_LOCATION_X				= 0
local DEPLOY_ZONE_LOCATION_Y				= -140
local DEPLOY_ZONE_WIDTH						= 480
local DEPLOY_ZONE_HEIGHT					= 100
local DEPLOY_ZONE_ART_PATH					= "resources/DeployZoneBackground.jpg"

local DEPLOY_ZONE_DISTANCE_BETWEEN_CARDS	= 100


--local CAPTURE_ZONE_LOCATION_X				= 0
local CAPTURE_ZONE_LOCATION_Y				= -10
local CAPTURE_ZONE_WIDTH					= 100
local CAPTURE_ZONE_HEIGHT					= 80
local CAPTURE_ZONE_ART_PATH					= "resources/CaptureZoneBackground.jpg"
local CAPTURE_ZONE_CARD_OFFSET_X			= 15
local CAPTURE_ZONE_CARD_OFFSET_Y			= -30

local CARD_AREA								= { PLAYER_DECK = 0, GLOBAL_DECK = 1, HAND = 2, DISCARD = 3, DEPLOY = 4, CAPTURE = 5, CAPTURE_PRIZE = 6 }

local game = {}
game.layerTable = nil

local mainLayer = nil
local card = nil
local textboxResources = nil
local textboxClock = nil
local processing = false

local grabbedCard = nil
local grabOffsetX = 0
local grabOffsetY = 0

local globalDeck = { }
local playerDeck = { }
local hand = { }
local discard = { }
local deployZone = { }

local captureCards = { }
for i=1, NUM_CAPTURE_CARDS do
	table.insert( captureCards, { } )
end

local captureZones = { }
for i=1, NUM_CAPTURE_CARDS do
	captureZones[i] = { }
	captureZones[i].prop = nil
	captureZones[i].cardTable = { }
end

local currentResources = 0

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

function GrabCard( card, x, y )
	grabbedCard = card

	local propLocX, propLocY = grabbedCard.prop:getLoc()
	grabOffsetX = propLocX - x
	grabOffsetY = propLocY - y
end

----------------------------------------------------------------
game.onInput = function ( self )

	if inputmgr:down() then
		-- check for a grabbed card from the hand
		local x, y = mainLayer:wndToWorld ( inputmgr:getTouch () )
		for k, v in ipairs(hand) do
			if v.prop:inside(x,y,0) then
				GrabCard( v, x, y )
			end
		end
		
		-- check for a grabbed card from the deploy zone
		if grabbedCard == nil then
			for k, v in ipairs(deployZone) do
				-- cards deployed this turn cannot be interacted with
				if not v.deployedThisTurn then
					if v.prop:inside(x,y,0) then
						GrabCard( v, x, y )
					end
				end
			end
		end
		
		-- check for a grabbed card from the capture zone
		if grabbedCard == nil then
			for i=1, NUM_CAPTURE_CARDS do
				for k, v in ipairs(captureZones[i].cardTable) do
					if v.prop:inside(x,y,0) then
						GrabCard( v, x, y )
					end
				end
			end
		end
		
	elseif inputmgr:up() then
		
		-- release the card
		if grabbedCard then
			
			cardHandled = false
			local x, y = mainLayer:wndToWorld ( inputmgr:getTouch () )
			-- check for Discard release
			if discardProp:inside(x,y,0) then
				print("Attempting Discard")
				-- can this card be discarded?
				cardHandled = AttemptDiscard( grabbedCard )
				if cardHandled then print("Card Discarded successfully") end
			-- check for Deployment release
			elseif deployZoneProp:inside(x,y,0) then
				print("Attempting Deployment")
				cardHandled = AttemptDeployment( grabbedCard )
				if cardHandled then print("Card Deployed successfully") end
			-- check for Capture release
			else
				for i=1, NUM_CAPTURE_CARDS do
					if captureZones[i].prop:inside(x,y,0) then
						print("Attempting Capture")
						cardHandled = AttemptMoveToCaptureZone( captureZones[i], grabbedCard )
						if cardHandled then print("Card Capture moved successfully") end
					end
				end
			end

			if not cardHandled then
				print("Card not handled - sending it back!")
				ReturnCardToOriginalLoc( grabbedCard )
			end
		else
			print("no grabbedCard to deal with")
		end
		
		grabbedCard = nil
		grabOffsetX = 0
		grabOffsetY = 0
	end
	
	-- send input to the End Turn button
	if inputmgr:up () then
		local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
		endTurnButton:updateClick ( false, x, y )
		
	elseif inputmgr:down () then
		local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
		endTurnButton:updateClick ( true, x, y )
	end

	-- update grabbed card
	if grabbedCard then
		local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
		print( x .. ', ' .. y )
		grabbedCard.prop:setLoc( x + grabOffsetX, y + grabOffsetY )
	end
end

---------------------------------------------------
function GetCardIndexInTable( card, cardTable )
	local cardIndex = 0
	for k, v in ipairs(cardTable) do
		if v == card then
			return k
		end
	end
	
	print("CARD CANNOT BE FOUND IN THE REQUIRED TABLE")
	return cardIndex
end


--------------------------------------------------
function ReturnCardToOriginalLoc( card )
	if card.cardArea == CARD_AREA.HAND then
		SendCardToHandLoc( grabbedCard )
	elseif card.cardArea == CARD_AREA.DEPLOY then
		SendCardToDeployZoneLoc( grabbedCard )
	elseif card.cardArea == CARD_AREA.CAPTURE then
		SendCardToCaptureZoneLoc( grabbedCard )
	end
end

--------------------------------------------------
function SendCardToHandLoc( card )
	local cardIndex = GetCardIndexInTable( card, hand )
	
	local destX, destY = GetCardHandLoc(cardIndex)
	print( "Sending Card to Hand - Card index: " .. cardIndex .. ", x = " .. destX .. ", y = " .. destY )

	card.prop:seekLoc(destX, destY, 1, MOAIEaseType.EASE_IN)
end

----------------------------------------------------------------
function SendCardToDeployZoneLoc( card )
	local cardIndex = 0
	for k, v in ipairs(deployZone) do
		if v == card then
			cardIndex = k
		end
	end
	
	local destX, destY = GetCardDeployZoneLoc(cardIndex)
	print( "Sending Card to Deploy Zone - Card index: " .. cardIndex .. ", x = " .. destX .. ", y = " .. destY )

	card.prop:seekLoc(destX, destY, 1, MOAIEaseType.EASE_IN)
end

----------------------------------------------------------------
function SendCardToCaptureZoneLoc( card )
	ArrangeCaptureZones()
end


----------------------------------------------------------------
game.onLoad = function ( self )

	self.layerTable = {}
	local layer = MOAILayer2D.new ()
	layer:setViewport ( viewport )
	game.layerTable [ 1 ] = { layer }
	
	local font =  MOAIFont.new ()
	font:loadFromTTF ( "arialbd.ttf", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.?! ", 12, 163 )
	
	textboxResources = MOAITextBox.new ()
	textboxResources:setFont ( font )
	textboxResources:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	textboxResources:setYFlip ( true )
	textboxResources:setRect ( -150, -230, 150, 230 )
	textboxResources:setLoc ( 0, 100 )
	textboxResources:setString ( "Resources - " .. currentResources )
	layer:insertProp ( textboxResources )
		
	textboxClock = MOAITextBox.new ()
	textboxClock:setFont ( font )
	textboxClock:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
	textboxClock:setYFlip ( true )
	textboxClock:setRect ( -150, -230, 150, 230 )
	textboxClock:setLoc ( 0, -100 )
	textboxClock:setString ( "Time to next click - " .. self.getTimeLeft () )
	--layer:insertProp ( textboxClock )

	--card = elements.makeButton( "CardTest.jpg", 90, 128 )
	--card:setCallback( function ( self )
	--	local thread = MOAIThread.new()
	--	thread:run( game.CardGrab )
	--end )
	--layer:insertProp ( card.img )
	
	mainLayer = layer
	
	-- create the global deck
	for i=1, 10 do local card = CardDatabase.CreateCard("Giant") table.insert(globalDeck, card) card.cardArea = CARD_AREA.GLOBAL_DECK end
	for i=1, 10 do local card = CardDatabase.CreateCard("Fighter") table.insert(globalDeck, card) card.cardArea = CARD_AREA.GLOBAL_DECK end
	for i=1, 10 do local card = CardDatabase.CreateCard("Turtle") table.insert(globalDeck, card) card.cardArea = CARD_AREA.GLOBAL_DECK end
	for i=1, 10 do local card = CardDatabase.CreateCard("Warhorse") table.insert(globalDeck, card) card.cardArea = CARD_AREA.GLOBAL_DECK end
	ShuffleDeck(globalDeck)
	
	-- create the player deck
	for i=1, 8 do local card = CardDatabase.CreateCard("Minion") table.insert(playerDeck, card) card.cardArea = CARD_AREA.PLAYER_DECK end
	for i=1, 2 do local card = CardDatabase.CreateCard("Bear") table.insert(playerDeck, card) card.cardArea = CARD_AREA.PLAYER_DECK end
	ShuffleDeck(playerDeck)

	InitializeDiscardZone()
	InitializePlayerDeckZone()
	InitializeGlobalDeckZone()
	InitializeDeployZone()
	InitializeCaptureCards()
	InitializeCaptureZones()
	InitializeEndTurnButton()
	
	-- draw the opening hand cards to start the turn!
	for i=1, HAND_SIZE do
		local card = DrawCardFromDeck( playerDeck, hand, discard, PLAYER_DECK_LOCATION_X, PLAYER_DECK_LOCATION_Y )
		card.cardArea = CARD_AREA.HAND
	end
	
	-- lay out the global cards
	
	
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

----------------------------------------------
function InitializeGlobalDeckZone()
	local globalDeckArt = MOAIGfxQuad2D.new()
	globalDeckArt:setTexture ( GLOBAL_DECK_ART_PATH )
	globalDeckArt:setRect( -45, -64, 45, 64 )
	
	globalDeckProp = MOAIProp2D.new()
	globalDeckProp:setDeck( globalDeckArt )
	globalDeckProp:setLoc( GLOBAL_DECK_LOCATION_X, GLOBAL_DECK_LOCATION_Y )
	
	mainLayer:insertProp( globalDeckProp )
end

---------------------------------------------
function InitializeDeployZone()
	local deployZoneArt = MOAIGfxQuad2D.new()
	deployZoneArt:setTexture ( DEPLOY_ZONE_ART_PATH )
	deployZoneArt:setRect( -(DEPLOY_ZONE_WIDTH/2), -(DEPLOY_ZONE_HEIGHT/2), DEPLOY_ZONE_WIDTH/2, DEPLOY_ZONE_HEIGHT/2 )
	
	deployZoneProp = MOAIProp2D.new()
	deployZoneProp:setDeck( deployZoneArt )
	deployZoneProp:setLoc( DEPLOY_ZONE_LOCATION_X, DEPLOY_ZONE_LOCATION_Y )
	
	mainLayer:insertProp( deployZoneProp )
end

---------------------------------------------
function InitializeCaptureCards()
	for k, v in ipairs(captureCards) do
		DrawNewCaptureCard( v, k )
	end
end

---------------------------------------------
function DrawNewCaptureCard( captureCardTable, captureCardTableIndex )
	local card = DrawCardFromDeck( globalDeck, captureCardTable, nil, GLOBAL_DECK_LOCATION_X, GLOBAL_DECK_LOCATION_Y )	
	card.cardArea = CARD_AREA.CAPTURE_PRIZE
	local x,y = GetCaptureCardLoc( captureCardTableIndex )
	card.prop:seekLoc( x, y, 1, MOAIEaseType.EASE_IN)
end

---------------------------------------------
function InitializeCaptureZones()
	for i=1, NUM_CAPTURE_CARDS do
		captureZones[i].prop = CreateNewCaptureZone(i)
	end
end

---------------------------------------------
function CreateNewCaptureZone( index )
	local captureZoneArt = MOAIGfxQuad2D.new()
	captureZoneArt:setTexture ( CAPTURE_ZONE_ART_PATH )
	captureZoneArt:setRect( -(CAPTURE_ZONE_WIDTH/2), -(CAPTURE_ZONE_HEIGHT/2), CAPTURE_ZONE_WIDTH/2, CAPTURE_ZONE_HEIGHT/2 )
	
	captureZoneProp = MOAIProp2D.new()
	captureZoneProp:setDeck( captureZoneArt )
	local x,y = GetCaptureCardLoc( index )
	captureZoneProp:setLoc( x, CAPTURE_ZONE_LOCATION_Y )
	
	mainLayer:insertProp( captureZoneProp )
	return captureZoneProp
end

---------------------------------------------
function InitializeEndTurnButton()

	local font =  MOAIFont.new ()
	font:loadFromTTF ( "arialbd.ttf", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.?! ", 12, 163 )

	endTurnButton = elements.makeTextButtonAtLocation ( font, "resources/button.png", END_TURN_BUTTON_WIDTH, END_TURN_BUTTON_HEIGHT, END_TURN_BUTTON_TEXT_Y, END_TURN_BUTTON_X, END_TURN_BUTTON_Y )
	endTurnButton:setString ( "EndTurn" )
	
	endTurnButton:setCallback ( function ( self )
		
		EndTurn()
		--local thread = MOAIThread.new ()
		--thread:run ( mainMenu.StartGameCloud, mainMenu.newGame )
		
	end )
	
	mainLayer:insertProp ( endTurnButton.img )
	mainLayer:insertProp ( endTurnButton.txt )
end

--------------------------------------------
function EndTurn()
	print("END TURN!")
	
	print("Num cards in hand: " .. #hand)
	while #hand > 0 do
		Discard( hand[#hand], hand )
		Yield( 5 )
	end
	print("Post discarding we have " .. #hand .. " cards in hand")
	
	Yield( 100 )
	
	ResolveCombat()
	
	Yield( 20 )
	
	for i=1, HAND_SIZE do
		local card = DrawCardFromDeck( playerDeck, hand, discard, PLAYER_DECK_LOCATION_X, PLAYER_DECK_LOCATION_Y )
		if card then
			card.cardArea = CARD_AREA.HAND
		end
	end
	
	for k, v in ipairs(deployZone) do
		v.deployedThisTurn = false
	end
	
	ArrangeHand()
	
	currentResources = 0
end

---------------------------------------------------------------
function ResolveCombat()
	for i=1, NUM_CAPTURE_CARDS do
		if #captureZones[i].cardTable > 0 then
			-- for now we'll capture this card with the cards we've placed into the capture zone
			for k, v in ipairs(captureZones[i].cardTable) do
				Discard( v, captureZones[i].cardTable )
				Yield( 5 )
			end
			
			captureCards
		end
		
		-- wait before moving onto the next column
		Yield( 10 )
	end
end



---------------------------------------------------------------
function DrawCardFromDeck( fromDeck, toLocation, discardPile, deckLocX, deckLocY )
	print("DRAWING CARD! num cards in deck = " .. #fromDeck)
	local numCardsInDeck = #fromDeck
	if numCardsInDeck == 0 then
		if discardPile == nil then
			print("No Discard Pile Exists!  Cannot draw a card!")
			return nil
		end
		
		if #discardPile == 0 then
			print("Discard Pile is empty! No cards for you!")
			return nil
		end
		
		print("Shuffling Discard into Deck!")
		ShuffleDiscardIntoDeck( fromDeck, discardPile, CARD_AREA.PLAYER_DECK )
	end
	
	local cardToDraw = fromDeck[1]
	table.insert( toLocation, cardToDraw )
	table.remove( fromDeck, 1 )
	
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
	
	cardToDraw.prop:setLoc( deckLocX, deckLocY )
	
	mainLayer:insertProp( cardToDraw.prop )
	
	print("POST DRAW! num cards in deck = " .. #fromDeck)
	
	return cardToDraw
end

-- attempt to discard the given card from the player's hand
-- if the card is discarded return true, otherwise return false
function AttemptDiscard( card )
	if card.cardArea == CARD_AREA.HAND and card.resourceAmount > -1 then
		currentResources = currentResources + card.resourceAmount
		
		Discard( card, hand )	
		
		ArrangeHand()
		return true
	end
	
	return false
end

-- attempt to deploy the given card from the player's hand to the deploy zone
-- if the card is deployed return true, otherwise return false
function AttemptDeployment( card )
	if card.cardArea == CARD_AREA.HAND and card.resourceCost <= currentResources then
		currentResources = currentResources - card.resourceCost
		
		Deploy( card )
		
		ArrangeDeployZone()
		ArrangeHand()
		return true
	end
	
	return false
end

-------------------------------------------------------------
function AttemptMoveToCaptureZone( captureZone, card )
	-- don't allow cards to move into capture zones if they were summoned this turn
	if card.deployedThisTurn then
		return false
	end
	
	-- only allow moves from the deploy or capture zones
	if  card.cardArea == CARD_AREA.DEPLOY or
		card.cardArea == CARD_AREA.CAPTURE then
		
		MoveToCaptureZone( captureZone, card )
		
		ArrangeDeployZone()
		ArrangeCaptureZones()
		
		return true
	end
	
	return false
end

-------------------------------------------------------------
function Discard( card, fromTable )
	print("Discarding " .. card.artName )

	local cardIndex = GetCardIndexInTable( card, fromTable )
	table.insert(discard, card)
	table.remove(fromTable, cardIndex)
	
	local easeDriver = card.prop:seekLoc ( DISCARD_LOCATION_X, DISCARD_LOCATION_Y, 0.5, MOAIEaseType.EASE_IN )
	easeDriver.card = card
	easeDriver:setListener( MOAIAction.EVENT_STOP, DestroyCardVisuals )
	
	-- spin the card as it goes to the discard pile!
	card.prop:moveRot( 360, 0.5, MOAIEaseType.SMOOTH )
		
	card.cardArea = CARD_AREA.DISCARD
end

-- callback that is used to destroy a card's visuals after it is discarded
function DestroyCardVisuals( self )
	mainLayer:removeProp( self.card.prop )
	self.card.prop = nil
	self.card = nil
end

-------------------------------------------------------------
function Deploy( card )
	print("Deploying" .. card.artName .. " from hand!")	

	card.deployedThisTurn = true
	table.insert(deployZone, card)
	local cardIndex = GetCardIndexInTable( card, hand )
	table.remove(hand, cardIndex)
	
	card.cardArea = CARD_AREA.DEPLOY
end

-------------------------------------------------------------
function MoveToCaptureZone( captureZone, card )
	print("Moving" .. card.artName .. " to the capture zone!")
	
	if card.cardArea == CARD_AREA.CAPTURE then
		local cardFound, captureZoneIndex, cardIndex = FindCardInCaptureZone( card )
		assert(cardFound)
		
		table.insert( captureZone.cardTable, card )
		table.remove( captureZones[captureZoneIndex].cardTable, cardIndex)
		
	elseif card.cardArea == CARD_AREA.DEPLOY then
		local cardIndex = GetCardIndexInTable( card, deployZone )	
		table.insert( captureZone.cardTable, card )
		table.remove( deployZone, cardIndex )
	end
	
	card.cardArea = CARD_AREA.CAPTURE
end


-------------------------------------------------------------
function FindCardInCaptureZone( card )
	assert(card.cardArea == CARD_AREA.CAPTURE, "Card is in the wrong area!")
	
	local cardFound = false
	local captureZoneIndex = 0
	local cardIndex = 0
	
	for i=1, NUM_CAPTURE_CARDS do
		for k, v in ipairs(captureZones[i].cardTable) do
			if card == v then
				assert(not cardFound, "Card found in multiple places!")
				cardFound = true
				captureZoneIndex = i
				cardIndex = k
			end
		end
	end
	
	return cardFound, captureZoneIndex, cardIndex
end


function FindCardIndex( card )
	-- let's go looking for this card!
	local cardFound = false
	local cardIndex = 0
	
	for k, v in ipairs(playerDeck) do
		if card == v then
			assert(v.cardArea == CARD_AREA.PLAYER_DECK, "Card is in the wrong area!")
			assert(not cardFound, "Card found in multiple places!")
			cardFound = true
			cardIndex = k
		end
	end
	
	for k, v in ipairs(hand) do
		if card == v then
			assert(v.cardArea == CARD_AREA.HAND, "Card is in the wrong area!")
			assert(not cardFound, "Card found in multiple places!")
			cardFound = true
			cardIndex = k
		end
	end

	for k, v in ipairs(globalDeck) do
		if card == v then
			assert(v.cardArea == CARD_AREA.GLOBAL_DECK, "Card is in the wrong area!")
			assert(not cardFound, "Card found in multiple places!")
			cardFound = true
			cardIndex = k
		end
	end
	
	for i=1, NUM_CAPTURE_CARDS do
		for k, v in ipairs(captureZones[i].cardTable) do
			if card == v then
				assert(v.cardArea == CARD_AREA.CAPTURE, "Card is in the wrong area!")
				assert(not cardFound, "Card found in multiple places!")
				cardFound = true
				cardIndex = k
			end
		end
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
function ShuffleDiscardIntoDeck( fromDeck, discardPile, newCardArea )
	-- move all discarded cards into the deck
	for k, v in ipairs(discardPile) do
		table.insert( fromDeck, v )
		v.cardArea = newCardArea
	end
	
	-- now go through and remove all of the card references from the discard pile
	while #discardPile > 0 do
		table.remove( discardPile, 1 )
	end
	
	-- now shuffle!
	ShuffleDeck( fromDeck )
end

------------------------------------------------------------
function GetCardHandLoc( cardIndex )
	local numCards = #hand
	local x = (cardIndex - ((numCards+1)/2)) * HAND_DISTANCE_BETWEEN_CARDS	
	local y = HAND_LOCATION_START_Y
	return x,y
end

------------------------------------------------------------
function GetCardDeployZoneLoc(cardIndex)
	local numCards = #deployZone
	local x = (cardIndex - ((numCards+1)/2)) * DEPLOY_ZONE_DISTANCE_BETWEEN_CARDS
	local y = DEPLOY_ZONE_LOCATION_Y
	return x,y
end

------------------------------------------------------------
function GetCaptureCardLoc( captureIndex )
	local x = (captureIndex - ((NUM_CAPTURE_CARDS+1)/2)) * CAPTURE_CARD_DISTANCE_BETWEEN_CARDS
	local y = CAPTURE_CARD_LOC_Y
	return x,y
end

------------------------------------------------------------
function ArrangeHand( )
	for k,v in ipairs(hand) do
		SendCardToHandLoc(v)
	end
end

----------------------------------------------------------------
function ArrangeDeployZone()
	for k,v in ipairs(deployZone) do
		SendCardToDeployZoneLoc(v)
	end
end

----------------------------------------------------------------
function ArrangeCaptureZones()
	for i=1, NUM_CAPTURE_CARDS do
		print( "Arranging Capture Zone for card: " .. i .. ". Cards assigned to capture = " .. #captureZones[i].cardTable )
		local numCards = #captureZones[i].cardTable
		local captureCardX = GetCaptureCardLoc( i )
		local captureCardY = CAPTURE_ZONE_LOCATION_Y
		
		for k, v in ipairs(captureZones[i].cardTable) do
			local x, y
			x = captureCardX + CAPTURE_ZONE_CARD_OFFSET_X * (k - 1)
			y = captureCardY + CAPTURE_ZONE_CARD_OFFSET_Y * (k - 1)
			
			v.prop:seekLoc(x, y, 1, MOAIEaseType.EASE_IN)
		end
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

	textboxResources:setString ( "Resources - " .. currentResources )
	textboxClock:setString ( "Time to next click - " .. self.getTimeLeft () )
end




function DumpCardTable( cardTable )
	for k, v in cardTable do
		print(v)
	end
end

function Yield( frames )
	for i=1, frames do coroutine.yield() end	
end

return game