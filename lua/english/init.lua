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

local function lua_init(argv)

	local function processor_func(key,env) -- key:KeyEvent,env_
		local k = {Rejected = 0, Accepted = 1, Noop = 2 }
		local context=env.engine.context 
		local composition=context.composition
		local keycode=key.keycode 

		
		if not  english_mode(env)  then return k.Noop end  
		if (key:ctrl() or key:alt() or key:release() ) then return k.Noop end 

		-- complate context.text  -- 
		local keyrepr=key:repr()
		log.info( "--processor in seg: (" .. tostring(context ) .. ")input: (" .. context.input  ..  ") keyrepr:(".. keyrepr ..")" )
		if  keyrepr == "Tab" then 
			local seg=composition:back()
			log.info( "seg: (" .. tostring(context ) .. ")input: (" .. context.input  ..  ") keyrepr:(".. keyrepr ..")" )
			local old_text=context.input 

			local cand=seg:get_selected_candidate( )
			---  complation  select cand
			if cand  and seg.selected_index == 0 and cand.type == "pre_english" then  
				local cand= seg:get_candidate_at(seg.selected_index +1 ) 
				if cand then context.input = cand.text end 
				--context:refresh_non_confirmed_composition()

			elseif cand and  seg.selected_index >0 then 
				context.input= cand.text
				--context:refresh_non_confirmed_composition()
			end 
			env.history_words:insert(old_text)
			return k.Accepted 
		end 

		log.info( "--process key:repr() :(" .. keyrepr .. ") history_words:" .. env.history_words:concat("|")  )  

		if keyrepr == "Shift+Tab" or keyrepr == "Shift_L+Tab" or keyrepr == "Shift_R+Tab"  then 
			local restore_text= env.history_words:remove()
			log.info( "--process in shift-tab key:repr() :(" .. keyrepr .. ") restore_tetxt:(" .. tostring(restore_text)  .. ") history_words:" .. env.history_words:concat("|")  )  
			if restore_text then 
				context.input= restore_text
				--context:refresh_non_confirmed_composition()
			end 
			return k.Accepted 
		end 

	
		local keychar= (keycode >=0x20 and keycode <0x80 and string.char(keycode) ) or ""
		--  如果 第一字母為 pucnt  直接上屏
		if not context:is_composing() and keychar:match("[%p ]") then return k.Rejected end  
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
		log.info("---processor in english_mode:" .. context.input ..    "  ascii(" .. keychar .. ")" ) 
		-- ascii   a-z A-Z_?*.-  
		if not  keychar:match([[^[%a%'?*_.-]$]]) then  return k.Noop end 
		context:push_input(keychar)
		log.info("---processor after in english_mode:" .. context.input ..    "  ascii(" .. keychar .. ")" ) 
		return k.Accepted 
	end  

	local function processor_init_func(env)
		env.history_words= setmetatable({} , {__index=table } ) 
		-- when  commit  clean 
		env.connection= env.engine.context.commit_notifier:connect(
			function(context)  
				env.history_words= setmetatable({} , {__index=table } ) 
			end )

		log.info("-- processor --- ") 
	end 
	local function processor_fini_func(env)
		env.connection:disconnect() 
		log.info("-- ~processor--- ") 
	end 


	-- lua segmentor
	local function segmentor_func(segs ,env) -- segmetation:Segmentation,env_
		local context=env.engine.context
		local cartpos= segs:get_current_start_position()


		
		if english_mode(env) and context:is_composing() then 
			local str = segs.input:sub(cartpos) 
			if not  str:match([[^%a[%a'?*_.-]*]]) then  return true  end 
		    local str= segs.input:sub(segs:get_current_start_position() )
			log.info("--segment  context_input: (" .. context.input .. ")  segs_input: (" .. segs.input .. ") preedit:" .. context:get_preedit().text )
			local seg=Segment(cartpos,segs.input:len())
			seg.tags=  Set({'english'})
			seg.prompt="(english)"
			segs:add_segment(seg) 
				
			return false 
		end 
		return true
	end 

	local function segmentor_init_func(env)
		log.info("-- segmentor--- ") 
	end 
	local function segmentor_fini_func(env)
		log.info("-- ~segmentor--- ") 
	end 
	-- lua translator 
	local function translator_func(input,seg,env)  -- input:string, seg:Segment, env_
		local context=env.engine.context
		
		if english_mode(env) and seg:has_tag("english")  then 
			log.info("-----entry lua_tranlator : english   input:(" .. input ..")" )
			local flag=true 
			input:find_words( 
			function(elm) 
				log.info("--- in tran yield loop -elm:" .. elm )
				if flag and input ~= elm then 
					yield( Candidate("pre_english", seg.start,seg._end , context.input , "[english]"))
				end 
				flag=false 
				yield( Candidate("english", seg.start,seg._end, elm, "[english]") )
			end 
			)

			log.info("-----exit lua_tranlato : english" )
		end 
	end 

	local function translator_init_func(env)
		log.info("-- translator--- ") 
	end 
	local function translator_fini_func(env)
		log.info("-- ~translator--- ") 
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
					log.info("-- in filter yield loop -cand: " .. cand.text .. ":" .. i .. ":" .. elm ) 
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
		env.connection= env.engine.context.commit_notifier:connect(
			function(context)  local cand=env.cand
				log.info( string.format(" ---notify %s %s %s %s " , cand.type,cand.text,cand.start,cand._end) )
				log.info( "---commit notifier :--" ..  context:get_commit_text() .. "--input:--" .. context.input .. "--"  )
				if english_mode(env) then 
					log.info( "---commit notifier :--" ..  context:get_commit_text() .. "--input:--" .. context.input .. "--"  )
				end 
			end )
		log.info("-- filter --- ") 
	end 
	local function filter_fini_func(env)  -- non return 
		env.connection:disconnect() 
		log.info("-- ~filter --- ") 
	end 



	local function load()
		english_processor= { func=processor_func, init=processor_init_func, fini=processor_fini_func}  
		english_segmentor= { func= segmentor_func, init=segmentor_init_func , fini=segmentor_fini_func}  
		english_translator={ func=translator_func, init=translator_init_func,fini=translator_fini_func}  
		english_filter=    { func=filter_func, init=filter_init_func,    fini=filter_fini_func }    

	end 
	local function unload()
		english_processor= { func=nil, init=nil, fini=nil}  
		english_segmentor= { func=nil, init=nil, fini=nil}  
		english_translator={ func=nil, init=nil, fini=nil}  
		esglish_filter=    { func=nil, init=nil, fini=nil}    
	end 

    if argv  then 
		unload()
	else 
		load()
	end 
	return { 
		processor= { func=processor_func, init=processor_init_func, fini=processor_fini_func} , 
		segmentor= { func= segmentor_func, init=segmentor_init_func , fini=segmentor_fini_func} , 
		translator={ func=translator_func, init=translator_init_func,fini=translator_fini_func} , 
		filter=    { func=filter_func, init=filter_init_func,    fini=filter_fini_func } ,   
	}

end 




return lua_init



