require "input"

MOAI_CLOUD_URL = "http://services.moaicloud.com/colond/clouddbtutorial"

MOAISim.openWindow( "Textboxes", 320, 480 )

viewport = MOAIViewport.new()
viewport:setScale( 320, 480 )
viewport:setSize( 320, 480 )

layer = MOAILayer2D.new()
layer:setViewport( viewport )
MOAISim.pushRenderPass( layer )

function UrlEscape(s)
	s = string.gsub(s, "([&=+%c])", function (c)
    		return string.format("%%%02X", string.byte(c))
		end)
	s = string.gsub(s, " ", "+")
	return s
end

function UrlEncode( t )
	local s = ""
		for k,v in pairs( t ) do
			s = s .. "&" .. UrlEscape( k ) .. "=" .. UrlEscape( v )
	end

	return string.sub ( s, 2 ) -- remove first '&'
end

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

io.write( "Please enter your name:" )
InputName = io.read()
print( "Your name is " .. InputName )

function taskCallback( task )
	print( task:getString() )
	text = task:getString()
	textbox:setString( text )
	layer:insertProp( textbox )
end

task = MOAIHttpTask.new()
task:setCallback( taskCallback )
url = UrlEncode( { name = InputName } )
print( url )
task:httpGet( MOAI_CLOUD_URL .. "?" .. url )

-- card image test
gfxQuad = MOAIGfxQuad2D.new ()
gfxQuad:setTexture ( "CardTest.jpg" )
--gfxQuad:setRect ( -128, -128, 128, 128 )
gfxQuad:setRect ( -89, -128, 89, 128 )
gfxQuad:setUVRect ( 0, 1, 1, 0 )

prop = MOAIProp2D.new ()
prop:setDeck ( gfxQuad )
layer:insertProp ( prop )

prop:setLoc( 0, 100 )
--prop:moveRot( 360, 5 )
--prop:moveLoc( 50, 50, 5 )