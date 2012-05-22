----------------------------------------------------------------
-- For more information on getting started with developing 
-- Moai Cloud applications, Lua environment, and API documentation, 
-- check out the following articles our blog and wiki:
--
-- Moai Cloud Documentation
-- http://getmoai.com/wiki/index.php?title=MoaiCloud
--
-- Using MongoDB with Moai Cloud
-- http://getmoai.com/wiki/Using_MongoDB_With_Moai_Cloud
--
-- Moai Cloud Lua Environment
-- http://getmoai.com/wiki/index.php?title=Using_MongoDB_With_Moai_Cloud
--
-- Support Forum
-- http://getmoai.com/forums/moai-cloud-developer-support.html
----------------------------------------------------------------

----------------------------------------------------------------
-- main() - (required) The primary entry point for a Moai Cloud application
----------------------------------------------------------------
function main(web, req)

	local params = web:params()
	local return_value = ""
 
	if( params.name ) then
		mongodb:update('names', {}, {name=params.name}, true, false)
                return_value = "Your name has been updated to:  " .. params.name
	else

                local cursor = mongodb:query('names', {})

		if( cursor:has_more() ) then
			local name_record = cursor:next()
			return_value = "You told us that your name is:  " .. name_record.name
		else
			return_value = "You haven't told us your name yet!"
		end 
	end
	 
	web:page(return_value, 200, 'OK')
end