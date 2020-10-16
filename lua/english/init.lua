#! /usr/bin/env lua
--
-- english.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

-- windows  path setup 

USERDIR= ( USERDIR or  os.getenv("APPDATA") or "" ) .. [[\Rime]]
local english_= "english"
local ascii_mode_ = "ascii_mode"
local pre_english_ = "pre_english" 
local toggle_key= "F10"
--require "english/english_init"
--string.find_word,string.word_info= require("english/english_dict")() 

require('english.english_init')
-- init  dictionary  function to string table 
string.find_words,string.word_info= require('english.english_dict')() -- (USERDIR .. "\\" .. [[lua\english\english.txt]] )
-- chcek mode   
local function english_mode(env)
	local ascii_mode= env.engine.context:get_option(ascii_mode_)
	local english_mode= env.engine.context:get_option(english_)
	return  english_mode   and   not ascii_mode
end 

local function lua_init()

	local function processor_func(key,env) -- key:KeyEvent,env_
		local k=env.k 
		local context=env.engine.context 
		local composition=context.composition
		local is_composing=context:is_composing()

		local function toggle_mode(ctx)
			local eng_mode= ctx:get_option(english_)
			local ascii_mode=ctx:get_option(ascii_mode_)
			if ascii_mode then  -- ascii_mode  to  chinese 
				ctx:set_option(english_, false)
				ctx:set_option(ascii_mode_,false)
			elseif not ascii_mode  and not eng_mode then  -- chinese mode to  english
				ctx:set_option(english_,true )
				--ctx:set_option(ascii_mode,false)
			elseif not ascii_mode and eng_mode then  --  english to ascii_mode
				ctx:set_option(english_, false)
				ctx:set_option(ascii_mode_,true)
			else
			end 


		end 
		--if context:is_composing() and  [,/. ] then
		local function   commit_chk(char) 
			if not is_composing  then return false end  
			if char:match([[^[,/ ]$]]  ) then  return true
			elseif  char == "."  and not context:has_menu() then return true
			else return false end  
		end 
		function commit_input()
			local cand= context:get_selected_candidate()
			context.input = (cand and cand.text ) or context.input  -- 更新 context.input
			context:commit() 
		end 
		local function complate_text() 

			local seg=context.composition:back()
			if not seg then return  end 
			local backup_input=context.input 
			
			-- 如果 cand 是第一個 且 type== "pre_english" 重取下一個 cand 補齊  
			if context:has_menu() then 
				local cand=seg:get_selected_candidate( )
				if  seg.selected_index == 0 and cand.type == pre_english_  then  
					 cand= seg:get_candidate_at(seg.selected_index +1 ) 
				 end 
				context.input= cand.text
				env.history_words:insert(backup_input)
			end 
		end 
		local function restort_word() 
			local restore_text= env.history_words:remove()
			if restore_text then 
				context.input= restore_text
				return restore_text
			end 
		end 
		local function hot_keyword(hotkey) 
			local wildword_ = env.keyname[hotkey] 
			env.history_words:insert(context.input)
			context.input = context.input  .. wildword_ 
			log.info( "-- hotkey enablecontext.input=" ..context.input .. "keyrepr:(" .. hotkey .. ")" )
		end 
		local function hotkey_cmd(hotkey)
			if  hotkey == "Tab" then  complate_text() 
			elseif  hotkey == "Shift+Tab" or hotkey== "Shift_L+Tab" or hotkey== "Shift_R+Tab"  then restort_word() 
			elseif  env.keyname[hotkey] then  hot_keyword(hotkey) 
			else 
				return  false
			end 
			return true
		end 
		--  toggle mode    ascii - chinese  -- english -- ascii 
		if key:repr() == toggle_key then  toggle_mode(context)   ; return k.Accepted  end 
		
		--if (key:ctrl() or key:alt() or key:release() ) then return k.Noop end 
		if not  english_mode(env)  then return k.Noop end  
		-- in english mode  
		if ( key:alt() or key:release() ) then return k.Noop end 


		-- is_composing status  and  keycode check  process
		local keycode=key.keycode 
		local keyrepr=key:repr()
		local keychar= (keycode >=0x20 and keycode <0x80 and string.char(keycode) ) or ""

		if is_composing then 
			--if keychar:match(",") then return k.Rejected end  
			-- commit char check  
			if  commit_chk(keychar)  then   commit_input() ; return k.Rejected end  --  
			--  hotkey check  and update context.input 
			log.info( "-- hotkey befor enable context.input=" ..context.input .. "keyrepr:(" .. keyrepr .. ")" )
			--  
			if hotkey_cmd( keyrepr) then return k.Accepted end 
		else 
			--  如果 第一字母為 pucnt  直接上屏
			if  keychar:match("[%p ]") then return k.Rejected end  


		end 
		--  input text mode 
		-- ascii   a-z A-Z_?*.-  
		if  keychar:match([[^[%a%:/'?*_.-]$]]) then  
			context:push_input(keychar)
			return k.Accepted
		else 
			return k.Noop  
		end 
		return k.Noop  
	end  

	local function processor_init_func(env)
		env.k = {Rejected = 0, Accepted = 1, Noop = 2 }
		env.keyname={ ["Control+f"] ="*ful" , ["Control+y"]= "*ly" , ["Control+n"]= "*tion" , ["Control+a"] = "*able" ,
		["Control+i"] = "*ing" , ["Control+m"]= "*ment"	, ["Control+r"]= "*er", 
	}
	env.history_words= setmetatable({} , {__index=table } ) 
	-- when  commit  clean 
	env.connection= env.engine.context.commit_notifier:connect(
	function(context)  
		env.history_words= setmetatable({} , {__index=table } ) 
	end )

end 
local function processor_fini_func(env)
	env.keyname=nil 
	env.connection:disconnect() 
end 


-- lua segmentor
local function segmentor_func(segs ,env) -- segmetation:Segmentation,env_
	local context=env.engine.context
	local cartpos= segs:get_current_start_position()



	if english_mode(env) and context:is_composing() then 
		local str = segs.input:sub(cartpos) 
		if not  str:match([[^%a[%a'?*_.-]*]]) then  return true  end 
		local str= segs.input:sub(segs:get_current_start_position() )
		local seg=Segment(cartpos,segs.input:len())
		seg.tags=  Set({'english'})
		seg.prompt="(english)"
		segs:add_segment(seg) 

		return false 
	end 
	return true
end 

local function segmentor_init_func(env)
end 
local function segmentor_fini_func(env)
end 
-- lua translator 
local function translator_func(input,seg,env)  -- input:string, seg:Segment, env_
	local context=env.engine.context

	if english_mode(env) and seg:has_tag(english_)  then 
		local flag=true 
		input:find_words( 
		function(elm) 
			if flag and input ~= elm then 
				yield( Candidate(pre_english_, seg.start,seg._end , context.input , "[english]"))
			end 
			flag=false 
			yield( Candidate(english_, seg.start,seg._end, elm, "[english]") )
		end 
		)

	end 
end 

local function translator_init_func(env)
end 
local function translator_fini_func(env)
end 

-- lua filter

--  cand data to string 
local function filter_func(input,env)  -- input:Tranlation , env_
	local i=0
	for cand in  input:iter() do 

		if cand.type== english_ then 
			i=i+1
			local commet=cand.text:word_info()
			commet:split("\\n"):each( function(elm) 
				--cand:get_genuine().comment= i .." : "   ..  elm
				local j= Candidate(cand.text,cand.start,cand._end,cand.text,i .. ":" .. elm) 
				yield(j) 
			end )

			--cand:get_genuine().comment= i .." : "   ..  cand.text:word_info()    
			--cand.comment= i .." : "   ..  cand.text:word_info() 
		else 
			yield(cand)
		end 
		env.cand=cand -- back last cand
	end 
end 

local function filter_init_func(env) -- non return 
	--env.connection= env.engine.context.commit_notifier:connect(
	--function(context)  local cand=env.cand
	--if english_mode(env) then 
	--log.info( "---commit notifier :--" ..  context:get_commit_text() .. "--input:--" .. context.input .. "--"  )
	--end 
	--end )
end 
local function filter_fini_func(env)  -- non return 
	--env.connection:disconnect() 
end 

return { 
	processor= { func=processor_func, init=processor_init_func, fini=processor_fini_func} , 
	segmentor= { func= segmentor_func, init=segmentor_init_func , fini=segmentor_fini_func} , 
	translator={ func=translator_func, init=translator_init_func,fini=translator_fini_func} , 
	filter=    { func=filter_func, init=filter_init_func,    fini=filter_fini_func } ,   
}

end 

local function init(tagname, unload_)
	local tab_= lua_init() 
	for k,v in pairs( tab_) do 
		local kk= tagname .. "_" .. k 
		_G[kk] =  ( not unload_ and  v ) or nil  --  load and v    or  nil 
		--log.info( "---key:" .. kk .. "lisk data:" .. tostring( _G[kk]) )
	end 


end 


return init



