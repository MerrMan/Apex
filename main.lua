--require "input"
require "urlEncode"

require "elements"
require "modules/cloud-manager"	
require "modules/state-manager"	
require "modules/input-manager"	
require "modules/savefile-manager"

MOAI_CLOUD_URL = "http://services.moaicloud.com/colond/clouddbtutorial"

MOAISim.openWindow( "APEX", SCREEN_WIDTH, SCREEN_HEIGHT )
--viewport = MOAIViewport.new()
--viewport:setSize ( SCREEN_WIDTH, SCREEN_HEIGHT )
--viewport:setScale ( SCREEN_UNITS_X, -SCREEN_UNITS_Y ) -- use negative Y axis
--viewport:setOffset( -1, 1 )

viewport = MOAIViewport.new ()
viewport:setSize ( 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT )
viewport:setScale ( SCREEN_UNITS_X, SCREEN_UNITS_Y )

-- seed random numbers
math.randomseed ( os.time ())

savefiles.get ( "user" )
globalData = {}

JUMP_TO = "states/state-menu.lua"
----------------------------------------------------------------
if 	JUMP_TO	then
	statemgr.push ( JUMP_TO )
----------------------------------------------------------------
else
	statemgr.push ( "states/state-splash.lua" )	
end
----------------------------------------------------------------

-- Start the game!
statemgr.begin ()


--[[
layer = MOAILayer2D.new()
layer:setViewport( viewport )
MOAISim.pushRenderPass( layer )

charcodes = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,:;!?()&/-'

font = MOAIFont.new ()

bitmapFontReader = MOAIBitmapFontReader.new ()
bitmapFontReader:loadPage ( 'FontVerdana18.png', charcodes, 16 )
font:setReader ( bitmapFontReader )

glyphCache = MOAIGlyphCache.new ()
glyphCache:setColorFormat ( MOAIImage.COLOR_FMT_RGBA_8888 )
font:setCache ( glyphCache )

textbox = MOAITextBox.new ()
--textbox:setString ( text )
textbox:setFont ( font )
textbox:setTextSize ( 16 )
textbox:setRect ( -150, -430, 150, 30 )
textbox:setAlignment ( MOAITextBox.CENTER_JUSTIFY, MOAITextBox.CENTER_JUSTIFY )
textbox:setYFlip ( true )
layer:insertProp ( textbox )

--io.write( "Please enter your name:" )
--InputName = io.read()
--print( "Your name is " .. InputName )

function taskCallback( task )
	print( task:getString() )
	text = task:getString()
	textbox:setString( text )
	layer:insertProp( textbox )
end

--task = MOAIHttpTask.new()
--task:setCallback( taskCallback )
--url = UrlEncode( { name = InputName } )
--print( url )
--task:httpGet( MOAI_CLOUD_URL .. "?" .. url )

-- card image test
gfxQuad = MOAIGfxQuad2D.new ()
gfxQuad:setTexture ( "CardTest.jpg" )
--gfxQuad:setRect ( -128, -128, 128, 128 )
--gfxQuad:setRect ( -89, -128, 89, 128 )
gfxQuad:setRect ( -45, -64, 45, 64 )
--gfxQuad:setUVRect ( 0, 1, 1, 0 )
gfxQuad:setUVRect ( 0, 0, 1, 1 )

prop = MOAIProp2D.new ()
prop:setDeck ( gfxQuad )
layer:insertProp ( prop )

prop:setLoc( 100, 100 )
--prop:moveLoc( 50, 50, 5 )
--updateCardPosition( prop, 0, 100 )

function updateCardPosition( prop, x, y )
    prop:setLoc( x, y )
end

mainThread = MOAICoroutine.new()
mainThread:run(
    function()
    	
    	local bGrabbedCard = false
    	local grabOffsetX = 0
    	local grabOffsetY = 0
    	
        local frames = 0
        while true do
            coroutine.yield()
            frames = frames + 1
            if (frames > 90) then
                frames = 0
                print('timer went off!')
            end
            
            -- grab the card with the left mouse button
            if (MOAIInputMgr.device.mouseLeft:down()) then
                local x,y =  MOAIInputMgr.device.pointer:getLoc()
                if prop:inside(x,y,0) then
                	bGrabbedCard = true
                	local propLocX, propLocY = prop:getLoc()
                	grabOffsetX = propLocX - x
                	grabOffsetY = propLocY - y
                end
            elseif (MOAIInputMgr.device.mouseLeft:isDown() == false) then
            	bGrabbedCard = false
            end

			-- spin the card with the right mouse button
           	if (MOAIInputMgr.device.mouseRight:down()) then
                local x,y =  MOAIInputMgr.device.pointer:getLoc()
                if prop:inside(x,y,0) then
	            	prop:moveRot( 360, 0.75 )
	            end
           	end           	
            
            if bGrabbedCard then
                local x,y =  MOAIInputMgr.device.pointer:getLoc()
                updateCardPosition( prop, x + grabOffsetX, y + grabOffsetY )
            end
        end
    end
)

]]--