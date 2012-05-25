--==============================================================
-- Copyright (c) 2010-2012 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
--==============================================================

local game = {}
game.layerTable = nil

local mainLayer = nil
local card = nil
local textboxClicks = nil
local textboxClock = nil
local processing = false

local cardGrabbed = false
local cardOffsetX = 0
local cardOffsetY = 0

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
end
----------------------------------------------------------------
game.onFocus = function ( self )
	
	MOAIGfxDevice.setClearColor ( 0, 0, 0, 1 )
end	

----------------------------------------------------------------
game.onInput = function ( self )

	-- lock input if client side time check is failing
	if ( self.getTimeLeft () <= 0 ) then
	
		-- send input to the card button
		if inputmgr:up () then
			local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
			card:updateClick ( false, x, y )
			
		elseif inputmgr:down () then
			local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
			card:updateClick ( true, x, y )
		end
	end
	
	if ( cardGrabbed == true ) then
		local x, y = mainLayer:wndToWorld ( inputmgr:getTouch ())
		print( x .. ', ' .. y )
		card.img:setLoc( x, y )
	end
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

	card = elements.makeButton( "CardTest.jpg", 90, 128 )
	card:setCallback( function ( self )
		local thread = MOAIThread.new()
		thread:run( game.CardGrab )
	end )
	
	layer:insertProp ( card.img )
	mainLayer = layer
	
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