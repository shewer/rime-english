#! /usr/bin/env lua
--
-- english.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

--require "english/english_init"
--string.find_word,string.word_info= require("english/english_dict")() 
require('english.english_init')
string.find_words,string.word_info= require('english.english_dict')() -- (USERDIR .. "\\" .. [[lua\english\english.txt]] )


local function english_mode(env)
	local context=env.engine.context
	local ascii_mode= context:get_option("ascii_mode")
	local _english_mode= context:get_option("english")
	return  _english_mode   --and   not ascii_mode

end 
local function exchange(tag,seg,flag)
	local segment=seg:back() 
	segment._end= segment._end +1
	segment.tags[tag]=true 

end 
local function lua_init()

	local function processor_func(key,env) -- key:KeyEvent,env_
		local k = {Rejected = 0, Accepted = 1, Noop = 2 }
		local context=env.engine.context 
		local composition=context.composition
		local keycode=key.keycode 
		--if true then return k.Noop end 

		if (key:ctrl() or key:alt() or key:release() ) then return k.Noop end 

		if not  english_mode(env)  then return k.Noop end  
		--log.info("---processor in  normorl )" ) 
		--log.info("---processor in inclish_mode   )" ) 
		local keychar= (keycode >=0x20 and keycode <0x80 and string.char(keycode) ) or ""
		if context:is_composing() and keychar == " " then
			local cand= context:get_selected_candidate()
			context.input= cand.text .. " " 
			--context:push_input(" ") 
			context:commit() 
			context:clear()
			return k.Accepted
		end 
		if not  keychar:match([[^[a-zA-Z._-?*]$]]) then  return k.Noop end 

		log.info("---processor in inclish_mode:" .. context.input ..    "  ascii(" .. keychar .. ")" ) 
		context:push_input(keychar)
		--context:confirm_previous_selection()

		--context.input= context.input .. keychar
		--context:refresh_non_confirmed_composition()

		log.info("---processor after in inclish_mode:" .. context.input ..    "  ascii(" .. keychar .. ")" ) 
		--if keychar:match([[^[ ,%d]$]]) then
		--return k.Noop
		--end 
		return k.Accepted 
	end  
	local function _processor_func(key,env)
		return 2
	end 

	local function processor_init_func(env)
	end 
	local function processor_fini_func(env)
	end 


	-- lua segmentor
	local function segmentor_func(segs ,env) -- segmetation:Segmentation,env_
		if english_mode(env) then 
			local context=env.engine.context
			if context:is_composing() then 

				log.info("--segment  context_input:" .. context.input .. "  segs_input:" .. segs.input .. " preedit:" .. context:get_preedit().text )
				if segs.empty() then 
					local seg=Segment(0,segs.input:len())
					seg.tags=  Set({'english'})
					segs:add_segment(seg) 
				else 
					local seg=segs:back()
					seg:reopen(input:len()) 
					seg.tags=  Set({'english'})

				end 
				return false

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
		if english_mode(env) then 
			log.info("-----entry lua_tranlator : english   input:(" .. input ..")" )
			local tags_= setmetatable(seg.tags,{__index=table })
			local tt=""
			for k,v in pairs(seg.tags) do 
				tt = tt ..  (v and tt .."|" .. k)  or  ""
			end 	
			log.info("-----entry lua_tranlator : english   input:(" .. input ..") tags=" .. tt )

			local type_= (seg:has_tag("english") and "english*" ) or  tt  
			yield( Candidate(type_ , seg.start, seg._end, input,type_ ) )  -- debug  and first 

			local context=env.engine.context
			if  true then  --seg:has_tag("abc")   then 
				--if  context:get_option("english")   then 
				local str= input:sub(seg.start,seg.start + seg.length) 

				str:find_words():each( 
				function(elm) 
					--log.info("--- in tran yield loop -elm:" .. elm )
					local cand =Candidate("english", seg.start,seg._end, elm, "[english]")
					yield( cand )
				end 
				)

			end 
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
		--env.dict= dict_info
		env.connection= env.engine.context.commit_notifier:connect(
		function(context)  local cand=env.cand
		log.info( string.format(" ---notify %s %s %s %s " , cand.type,cand.text,cand.start,cand._end) )
		log.info( "---commit notifier :--" ..  context:get_commit_text() .. "--input:--" .. context.input .. "--"  )
		if english_mode(env) then 
			log.info( "---commit notifier :--" ..  context:get_commit_text() .. "--input:--" .. context.input .. "--"  )
			
			--context:push_input("  ") 
		end 
		end 
		)
	end 
	local function filter_fini_func(env)  -- non return 
		env.connection:disconnect() 
	end 






	return { 
		processor= { func=processor_func, init=processor_init_func, fini=nil } , 
		segmentor= { func= segmentor_func, init=segmentor_init_func , fini=nil} , 
		translator={ func=translator_func, init=translator_init_func,fini=nil } , 
		filter=    { func=filter_func, init=filter_init_func,    fini=nil } ,   
	}

end 




return lua_init



