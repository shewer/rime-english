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
	log.info= function(str) print(str) end 

end 

print( "---filename :" , string.gsub(debug.getinfo(1).source, "^@(.+/)[^/]+$", "%1english.txt") )
--USERDIR= ( USERDIR or  os.getenv("APPDATA") or "" ) .. [[\Rime]]

-- 字典 字根 查碼 table
--  
--local eng_suffixe1={ ["Control+f"] ="*ful" , ["Control+y"]= "*ly" , ["Control+n"]= "*tion" , ["Control+a"] = "*able" ,
--["Control+i"] = "*ing" , ["Control+m"]= "*ment"	, ["Control+r"]= "*er", }
--env.keyname2={ f ="*ful" , y= "*ly" , n= "*tion" , a = "*able" ,
--i = "ing" , m= "*ment"	, r= "*er", 
--}
--   f="ful"  --> /f or   Control+f  
require 'tools/object'





local eng_suffix={ f ="ful" , y= "ly" , n= "tion" , a = "able" ,
i = "ing" , m= "ment"	, r= "er", g="ght" ,  l="less" ,  }
local eng_suffix_list={ }

-- 詞類
local eng_parts={ "a", "abbr", "ad", "art", "aux", "phr", "pl", "pp", "prep", "pron", "conj", "int", "v", "vi", "vt"   }
setmetatable(eng_parts,{__index=table } )



--require 'english/english_init'
local function parts_find(str)
	local part= eng_suffix[str] 
    return  "*" .. ( part  or str )

end
-- split    word/p1/p2:p3   ex: a*/tion:n    action:n  
local function check_slash(input)
	local w,p1,p2,p3
	w,p3=input:split(":"):unpack()
	w,p1,p2=w:split("/"):unpack()
	w= w or ""
	p1= "*" .. ( eng_suffix[p1] or p1 or  "" ) 
	p2= "*" .. ( eng_suffix[p2] or p2 or  "" ) 
	p3 = p3 or ""
	p3 = p3=="" and  p3  or  ( " " .. p3 .. "[%w]*%.%s")  
	return w, p1,p2,p3
end 
local function wildfmt(str)  --    replace ?* to pattern    ? => [%a._]?   *=> [%a._]*   and  add  "$"
	local w,p1,p2,p3= check_slash(str)
	local wild_word= (w .. p1 .. p2)
	-- replase  ?*    
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

local function init_dict(filename ) 
	local function split_info(info_str)
		local info={phonics="",info=""}
		local  head,tail=  info_str:find('^%[[^%s]*]') 
		if head and tail then 
			info.phonics= info_str:sub(head,tail)
			info.info= info_str:sub(tail+1)
		end 
		return info
	end 


	--local dict_file= io.open( ( SERDIR .. "/" .. filename) )
	local dict_info=setmetatable({},{__index=table})
	-- create  a-z dict_tab  { a= dict_a , b=dict_b ..... ,z=dict_z}
	local dict_index=setmetatable({},{__index=table})
	for i=0x61,0x7a do  -- a-z 
		dict_index[string.char(i)] = setmetatable({},{__index=table})
	end

	filename =  filename or string.gsub(debug.getinfo(1).source, "^@(.+/)[^/]+$", "%1english.txt") 
	local dict_file=  io.open( filename)
	if not dict_file then 
		log.info("=English module open file not found: " .. filename)
	else 
		log.info( ( "=English module load english.txt : %s (%s)"):format(  filename,dict_file )) 
		-- init dict_index and dict_info
		for line in dict_file:lines() do 
			if not line:match("^#") then 
				local word,pre_info = line:split("\t"):unpack()
				dict_info[word]= split_info(pre_info) 
				dict_index[word:sub(1,1):lower() ]:insert(word)
				--dict_index:insert(word)
			end 
		end 
	end 
	return dict_index,dict_info

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



local English= Class("English")
function English:_initialize(filename)
	self._dict_index, self._dict_info = self.Parse(filename)
	self._mode=0
	return self
end 

function English.Parse(filename) -- return table ,table
	return init_dict(filname)
end 
function English:mode(mode)
	if  ( mode and tonumber( mode ) ) then 
		if mode >= 0 and  mode <= 3 then self._mode= mode  end
	end 
	return self._mode
end 

function English:info(word,mode) -- return string  , string
	local info= self._dict_info[word]
	if not info then return  "" end 
	mode= mode or self:mode() 
	if mode == 1 then 
	    return info.phonics .. info.info, word
	else 
		return info.info ,word
	end 
end 

function English:iter(s_word,mode)
	local function _check_dict(word,pattern,part)
		return word:lower():match(pattern) and self:info(word):match(part) 
	end 
	return coroutine.wrap( function() 
		local words=self._dict_index[s_word:sub(1,1):lower()]  or setmetatable({} , {__index=table} ) 
		--local info=self._dict_info
		if not words then 
			log.info( string.format( "tabsize=0 :string = (%s), sub=(%s) ", s_word , s_word:sub(1,1) ))
			return 
		end 
		local patternstr,wildstr, part=wildfmt(s_word) 

		for i,word in ipairs(words) do 
			if  _check_dict(word,patternstr,part ) then 
					coroutine.yield({word= word, info=self:info(word,mode)})
			end 
		end 
	end )
end 

function English:dict_match(word,func)   -- iter yield { word= , info= ...} 
	local tab_result=setmetatable({} , {__index=table} ) 
	func= func or function(elm)  return elm end 
	for elm  in  self:iter(word) do
		tab_result:insert( func(elm) )
	end 
	return tab_result
end 
English.Wildfmt= wildfmt    -- alias Wildfmt = wildfmt










return English


--return init

