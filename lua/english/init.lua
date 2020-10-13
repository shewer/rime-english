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

local function lua_init()

	local function processor_func(key,env) -- key:KeyEvent,env_
		local k = {Rejected = 0, Accepted = 1, Noop = 2 }
		local context=env.engine.context 
		local composition=context.composition
		local keycode=key.keycode 

		
		if (key:ctrl() or key:alt() or key:release() ) then return k.Noop end 

		if not  english_mode(env)  then return k.Noop end  
		--log.info("---processor in  normorl )" ) 
		--log.info("---processor in inclish_mode   )" ) 

		-- complate context.text  -- 
		if  key:repr() == "Tab" then 
			local seg=composition:back()
			local cand=seg:get_candidate_at( seg.selected_index +1 ) 
			if cand  then  context.input= cand.text end  
			return k.Accepted 
		end 

		local keychar= (keycode >=0x20 and keycode <0x80 and string.char(keycode) ) or ""
		-- non_ascii code  
		-- commit processor   "[, ]"
		if context:is_composing() and keychar:match([[^[, ]$]])  then

			local cand= context:get_selected_candidate()
			context.input = (cand and cand.text ) or context.input
			context:push_input(keychar) 
			context:commit() 
			context:clear()
			return k.Accepted
		end 
		log.info("---processor in inclish_mode:" .. context.input ..    "  ascii(" .. keychar .. ")" ) 
		-- ascii   a-z A-Z_?*.-  
		if not  keychar:match([[^[a-zA-Z_?*.-]$]]) then  return k.Noop end 
		context:push_input(keychar)
		log.info("---processor after in inclish_mode:" .. context.input ..    "  ascii(" .. keychar .. ")" ) 
		return k.Accepted 
	end  

	local function processor_init_func(env)
	end 
	local function processor_fini_func(env)
	end 


	-- lua segmentor
	local function segmentor_func(segs ,env) -- segmetation:Segmentation,env_
		local context=env.engine.context
		if english_mode(env) and context:is_composing() then 
			log.info("--segment  context_input:" .. context.input .. "  segs_input:" .. segs.input .. " preedit:" .. context:get_preedit().text )
			if segs.empty() then 
				local seg=Segment(0,segs.input:len())
				seg.tags=  Set({'english'})
				seg.prompt="(english)"
				segs:add_segment(seg) 
				
			else 
				local seg=segs:back()
				seg:reopen(input:len()) 
				seg.prompt="(english)"
				seg.tags=  Set({'english'})

			end 
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
			log.info("-----entry lua_tranlator : english   input:(" .. input ..")" )
			local flag=true 
			input:find_words( 
			function(elm) 
				log.info("--- in tran yield loop -elm:" .. elm )
				if flag and context.input ~= elm then 
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
				commet:split("\n"):each( function(elm) 
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
	end 
	local function filter_fini_func(env)  -- non return 
		env.connection:disconnect() 
	end 






	return { 
		processor= { func=processor_func, init=processor_init_func, fini=processor_fini_func} , 
		segmentor= { func= segmentor_func, init=segmentor_init_func , fini=segmentor_fini_func} , 
		translator={ func=translator_func, init=translator_init_func,fini=translator_fini_func} , 
		filter=    { func=filter_func, init=filter_init_func,    fini=filter_fini_func } ,   
	}

end 




return lua_init



