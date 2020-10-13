#! /usr/bin/env lua
--
-- english_dict.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--
if not log then 
	log={}
end 
if not log.info  then 
	log.info= function(str) print(str) end 
end 
USERDIR= ( USERDIR or  os.getenv("APPDATA") or "" ) .. [[\Rime]]

require 'english/english_init'
local function wildfmt(str)  --    replace ?* to pattern    ? => [%a._]?   *=> [%a._]*   and  add  "$"
		local change
		str,change= str:gsub("([?*])","[%%a._]%1")
		if change > 0 then 
			str=   str .. "$"
		end 
		return "^" .. str:lower()
end 
--- 取消  match()     inline to  dict_match() 
local function match( str )
	str= wildfmt(str) 
	return function(elm)
		return   elm:lower():match( "^" .. str ) 
	end 
end 

local function init_dict(filename ) 

	filename= filename or  ( USERDIR .. "\\" .. [[\lua\english\english.txt]]) 


	local dict_file=  io.open( filename)
	log.info("english.txt : " .. filename ) 
	log.info("open dict_file :  " .. tostring(dict_file)  ) 
	--local dict_file= io.open( ( USERDIR .. "/" .. filename) )
	local dict_index=setmetatable({},{__index=table})
	local dict_info=setmetatable({},{__index=table})
	for i=0x61,0x7a do  -- a-z 
		dict_index[string.char(i)] = setmetatable({},{__index=table})
	end
	for line in dict_file:lines() do 
		if not line:match("^#") then 
			local word,info = line:split("\t"):unpack()
			dict_info[word]=info
			dict_index[word:sub(1,1):lower() ]:insert(word)
			--dict_index:insert(word)
	    end 
	end 
	return dict_index,dict_info

end 

local function dict_match(tab, str,step)
	tab=tab[str:sub(1,1):lower()]  or setmetatable({} , {__index=table} ) 
	if #tab==0  then 
		log.info(
		      string.format( "tabsize=0 :string = (%s), sub=(%s) ", str , str:sub(1,1) )
		)
	end 
	if step then 
		for i=1,#str do 
			local substr= str:sub(1,i) 
			tab=tab:find_all( match( substr ) )
		end 
	else 
		--tab = tab:find_all(match( str) )
		str=wildfmt(str) 
		tab = tab:find_all( function(elm) 
			return   elm:lower():match( str ) 
			end )

    end 
	return tab  or setmetatable( {} , {__index=table })
end 


local function init(filename)

	local dict_index,dict_info = init_dict(filename) 

	local function words(str) 
		return dict_match(dict_index,str)
	end 
	local function info(str)
		return dict_info[str]
	end 
	local function unload()
		package.loaded["english_dict"]=nil 
	end 
		
	return words,info ,unload
end 
return init

