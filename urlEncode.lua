-- functions to encode a url for sending to moai cloud

function UrlEncode( t )
	local s = ""
		for k,v in pairs( t ) do
			s = s .. "&" .. UrlEscape( k ) .. "=" .. UrlEscape( v )
	end

	return string.sub ( s, 2 ) -- remove first '&'
end

function UrlEscape(s)
	s = string.gsub(s, "([&=+%c])", function (c)
    		return string.format("%%%02X", string.byte(c))
		end)
	s = string.gsub(s, " ", "+")
	return s
end


