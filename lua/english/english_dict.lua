#! /usr/bin/env lua
--
-- english_dict.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

-- environment setting
-- rime log  redefine 
if not log then 
	log={}
end 
if not log.info  then 
	log.info= function(str) print(str) end 
end 

USERDIR= ( USERDIR or  os.getenv("APPDATA") or "" ) .. [[\Rime]]

-- 字典 字根 查碼 table
--  
local eng_suffixe1={ ["Control+f"] ="*ful" , ["Control+y"]= "*ly" , ["Control+n"]= "*tion" , ["Control+a"] = "*able" ,
["Control+i"] = "*ing" , ["Control+m"]= "*ment"	, ["Control+r"]= "*er", }
--env.keyname2={ f ="*ful" , y= "*ly" , n= "*tion" , a = "*able" ,
--i = "ing" , m= "*ment"	, r= "*er", 
--}
local eng_suffix={ f ="ful" , y= "ly" , n= "tion" , a = "able" ,
i = "ing" , m= "ment"	, r= "er", g="ght" ,  l="less" ,  }
local eng_suffix_list={ }

-- 詞類
local eng_parts={ "a", "abbr", "ad", "art", "aux", "phr", "pl", "pp", "prep", "pron", "conj", "int", "v", "vi", "vt"   }
setmetatable(eng_parts,{__index=table } )



require 'english/english_init'
local function check_slash(input)
	local w,p1,p2,p3
	w,p3=input:split(":"):unpack()
	w,p1,p2=w:split("/"):unpack()
	w= w or ""
	p1=p1 or ""
	p2=p2 or ""
	p3=p3 or ""
	return w, p1,p2,p3
end 
local function parts_find(str)
	local part= eng_suffix[str] 
	if part then 
		return  "*" .. part 
	end 
	return ""
end
local function wildfmt(str)  --    replace ?* to pattern    ? => [%a._]?   *=> [%a._]*   and  add  "$"
	local w,p1,p2,p3= check_slash(str)
	local wild_word= (w .. parts_find(p1) .. parts_find(p2))

	local pattern_word, change= wild_word:lower():gsub("([?*])","[%%a._]%1")
	pattern_word, change= pattern_word:gsub("([._-])","%%%1")
	pattern_word = "^" .. pattern_word 
	if change > 0 then 
		--str=   str .. "$"
	end 
	return  pattern_word ,wild_word , p3
end 

-- when  commit  clean 
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

local function dict_match(tab, str,func)
	tab=tab[str:sub(1,1):lower()]  or setmetatable({} , {__index=table} ) 
	if #tab==0  then 
		log.info( string.format( "tabsize=0 :string = (%s), sub=(%s) ", str , str:sub(1,1) ))
	end 
	--if str:len() == 1 or #tab == 0 then  --   pass find_all function 
		--tab:each ( function(elm)  func(elm,"") end  )
	--else
		--tab = tab:find_all(match( str) )
		local patternstr,wildstr, part=wildfmt(str) 
		tab = tab:find_all( function(elm) 
			local match_str= elm:lower():match( patternstr ) 
			if type(func) == "function"  and match_str  then func( elm, part) end 
			return  match_str 
		end )
	--end 
	return tab  or setmetatable( {} , {__index=table })
end 

local function dict_match_call(tab,str , func)
	tab=tab[str:sub(1,1):lower()]  or setmetatable({} , {__index=table} ) 
	str=wildfmt(str)
	tab:each( func)
end 	      


local function init(filename)

	local dict_index,dict_info = init_dict(filename) 

	local function words(str,func) 
		return dict_match(dict_index,str, func)
	end 
	local function info(str,func,part,splite_f)
		part = part  or ""
		local info=dict_info[str] or ""
		if not func then 
			return  info
		end 
		local tab_ = ( splite_f and info:split("\n") ) or setmetatable({ info} , {__index=table}) 
		if part == "" then 
			tab_:each( function(info_elm)  
				func(info_elm,str)  
			end )
		else

			local parts=eng_parts:find_all( function(elm,str) return elm:match("^" .. str ) end,part )
			tab_:each( function(info_elm) 
				local match_f= parts:find( function(elm) info_elm:match("%s" .. elm .. "%.") end )  
				if match_f then func(info_elm,str)  end 
			end)
		end
		--info( function(elm,str)   end , split_f, part) 
		--return dict_info[str]
		return info

	end 
	local function _iter_match_func(tab, str, func ) 
		local iter,tab,index = ipairs(tab)
		return function()
			for i,v in iter ,tab, index do
				index = i  -- keep index for next start from index+1 
				if  v:lower():match( str ) then 
					return func(v) 
				end 
			end 
			return nil 
		end 
	end 
	local function keep_cand(comment,part)
		if not part  or part=="" then  return ture end 
		local parts=eng_parts:find_all( function(elm,str) return elm:match("^" .. str ) end,part )
		local result=parts:find(function(elm,str) return str:match( "%s" .. elm .. "%." ) end , part)  
		return result
	end 
		
	local function _iter_match(str, func ) -- pattern_sttr 
		local tab= dict_index[str:sub(1,1)]  or setmetatable({},{__index=table})
		local pattern_str, wild_str, part = wildfmt(str) 
		print( "local tab:" , tab , "size:" , #tab) 
		print("wildfmt return: ",pattern_str, wild_str,part)
		return _iter_match_func(tab,pattern_str,func)
	end 

	local function part_match(info, part)
		part= part or ""
		if #part > 0 then 
			return info:match( "%s" ..  part:lower() .. "%.%s" ) 
		end 
		return true
	end 

	local function iter_dict_match(str,split)   -- "Ab/i:a"
		local pattern_str, wild_str, part = wildfmt(str) 
		local tab = dict_index[ str:sub(1,1):lower() ] or setmetatable({},{__index=table})

		return coroutine.wrap( function() 
			for i,word  in ipairs(tab) do 
				if  word:lower():match( pattern_str ) then 
					
					local info= dict_info[word] or ""
					if split then 
						info:split("\\n"):each( function( info) 
							if part_match(info, part) then  coroutine.yield(word,info) end 
						end )

						--for i,sub_info in ipairs( info:split("\\n") ) do 
							--if part_match(sub_info, part) then 	coroutine.yield(word,sub_info) end 
						--end 
					else 
						if part_match(info, part) then  coroutine.yield(word,info) end 
					end 
				end 
			end 
			return nil 
		end )
			
	end 



	local function unload()
		package.loaded["english_dict"]=nil 
	end 
	local dict={words=words,info=info, part_word=parts_find , wildfmt=wildfmt ,iter_match1=iter_match1,iter_match=iter_match,iter_match_=iter_match_, check_slash=check_slash ,keep_cand=keep_cand,iter_dict_match=iter_dict_match}

	--return dict,unload 
	return dict,unload ,dict_index,dict_info 
end 
return init

