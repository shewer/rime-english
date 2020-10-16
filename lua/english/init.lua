#! /usr/bin/env lua
--
-- english.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

-- windows  path setup 
USERDIR= ( USERDIR or  os.getenv("APPDATA") or "" ) .. [[\Rime]]

--require "english/english_init"
--string.find_word,string.word_info= require("english/english_dict")() 

require('english.english_init')
-- init  dictionary  function to string table 
string.find_words,string.word_info= require('english.english_dict')() -- (USERDIR .. "\\" .. [[lua\english\english.txt]] )

-- chcek mode   
local function english_mode(env)
	local context=env.engine.context
	local ascii_mode= context:get_option("ascii_mode")
	local _english_mode= context:get_option("english")
	return  _english_mode   and   not ascii_mode

end 
local function toggle_mode(ctx)
	local english_ =ctx:get_option("english")
	local ascii_ =ctx:get_option("ascii_mode")
	if ascii_ then  -- ascii_mode to chinese
		ctx:set_option("english", false )
	    ctx:set_option("ascii_mode", false)
    elseif not ascii_ and not english_ then  -- chinese to  english 
		ctx:set_option("english", true)
	elseif not ascii_ and  english_ then   -- english to ascii_mode
		ctx:set_option("english", false )
	    ctx:set_option("ascii_mode", true)
	end 
	--return 1 -- accepted

end 

local function lua_init()

	local function processor_func(key,env) -- key:KeyEvent,env_
		local k = {Rejected = 0, Accepted = 1, Noop = 2 }
		local context=env.engine.context 
		local composition=context.composition
		local keycode=key.keycode 
		local is_composing=context:is_composing()
		local keyrepr=key:repr()
		if  key:alt() or key:release()  then return k.Noop end 
		--if keycode == 0xff30  and  key:ctrl() and  keyrepr == "Control+Control_L" then 
		if  key:ctrl() and key:ctrl() and  keyrepr == "Control+Control_L" then  
			log.info( "-- hotkey befor enable context.input=" ..context.input .. "keyrepr:(" .. keyrepr .. ")" )
				toggle_mode(context) 
				return k.Accepted
		end 

		if not  english_mode(env)  then return k.Noop end  
		--if (key:ctrl() or key:alt() or key:release() ) then return k.Noop end 


		log.info( "-- hotkey befor enable context.input=" ..context.input .. "keyrepr:(" .. keyrepr .. ")" )
		if is_composing and env.hotkey[keyrepr] then
			local old_text=context.input
			context.input = old_text  .. env.hotkey[keyrepr] 
			env.history_words:insert(old_text)
			log.info( "-- hotkey enablecontext.input=" ..context.input .. "keyrepr:(" .. keyrepr .. ")" )
			return k.Accepted 
		end 
		-- complate context.text  -- 
		if  keyrepr == "Tab" then 
			local seg=composition:back()
			local old_text=context.input 

			local cand=seg:get_selected_candidate( )
			if cand  and seg.selected_index == 0 and cand.type == "pre_english" then  
				local cand= seg:get_candidate_at(seg.selected_index +1 ) 
				if cand then context.input = cand.text end 

			elseif cand and  seg.selected_index >0 then 
				context.input= cand.text
			end 
			env.history_words:insert(old_text)
			return k.Accepted 
		end 


		if keyrepr == "Shift+Tab" or keyrepr == "Shift_L+Tab" or keyrepr == "Shift_R+Tab"  then 
			local restore_text= env.history_words:remove()
			if restore_text then 
				context.input= restore_text
			end 
			return k.Accepted 
		end 
		


		local keychar= (keycode >=0x20 and keycode <0x80 and string.char(keycode) ) or ""
		--  如果 第一字母為 pucnt  直接上屏
		if not is_composing and keychar:match("[%p ]") then return k.Rejected end  
		-- non_ascii code  
		-- commit processor   "[, ]"
		--if context:is_composing() and okeychar:match([[^[, ]$]])  then
		local function context_commit(ctx,char) 
			local cand= ctx:get_selected_candidate()
			ctx.input = (cand and cand.text ) or ctx.input  -- 更新 context.input
			ctx:commit() 
			--ctx:push_input(char) 
			return k.Rejected
		end 

		--if keychar:match(",") then return k.Rejected end  

		if  keychar:match([[^[ ]$]]) and  context:is_composing()  then context_commit(context,keychar) end 
		-- ascii   a-z A-Z_?*.-  
		if not  keychar:match([[^[%a%'?*_.-]$]]) then  return k.Noop end 
		context:push_input(keychar)
		return k.Accepted 
	end  

	local function processor_init_func(env)
		env.history_words= setmetatable({} , {__index=table } ) 
		env.hotkey= { ["Control+f"] ="*ful" , ["Control+y"]= "*ly" , ["Control+n"]= "*tion" , ["Control+a"] = "*able" ,
					["Control+i"] = "*ing" , ["Control+m"]= "*ment"	, ["Control+r"]= "*er", 
			}
		-- when  commit  clean 
		env.connection= env.engine.context.commit_notifier:connect(
		function(context)  
			env.history_words= setmetatable({} , {__index=table } ) 
		end )

	end 
	local function processor_fini_func(env)
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

		if english_mode(env) and seg:has_tag("english")  then 
			local flag=true 
			input:find_words( 
			function(elm) 
				if flag and input ~= elm then 
					yield( Candidate("pre_english", seg.start,seg._end , context.input , "[english]"))
				end 
				flag=false 
				yield( Candidate("english", seg.start,seg._end, elm, "[english]") )
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

			if cand.type== "english" then 
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



