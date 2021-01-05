#! /usr/bin/env lua
--
-- english.lua
-- Copyright (C) 2020 Shewer Lu <shewer@gmail.com>
--
-- Distributed under terms of the MIT license.
--

-- windows  path setup 

--USERDIR= ( USERDIR or  os.getenv("APPDATA") or "" ) .. [[\Rime]]
USERDIR= rime_api.user_dir()

local English= "english"
local Ascii_mode = "ascii_mode"
local Pre_english = "pre_english" 
local Fold_sw = "fold_comments"
local Toggle_fold_key= "F9" 
local Toggle_key= "F10"
--require "english/english_init"
--string.find_word,string.word_info= require("english/english_dict")() 

--require('english.english_init')
-- init  dictionary  function to string table 
--local dict= require('english.english_dict')() -- (USERDIR .. "\\" .. [[lua\english\english.txt]] )
--string.find_words,string.word_info,string.iter_match= dict.words,dict.info,dict.iter_match
--string.wildfmt=dict.wildfmt
--string.wildfmt=dict.iter_dict_match
-- chcek mode   
local function english_mode(env)
	local ascii_mode= env.engine.context:get_option(Ascii_mode)
	local english_mode= env.engine.context:get_option(English )
	return  english_mode   and   not ascii_mode
end 
local function toggle_mode(env)
	local context=env.engine.context
	local eng_mode=context:get_option(English )
	local ascii_mode=context:get_option(Ascii_mode)
	if ascii_mode then  -- ascii_mode  to  chinese 
		context:set_option(English , false)
		context:set_option(Ascii_mode,false)
	elseif not ascii_mode  and not eng_mode then  -- chinese mode to  english
		context:set_option(English ,true )
		--context:set_option(ascii_mode,false)
	elseif not ascii_mode and eng_mode then  --  english to ascii_mode
		context:set_option(English , false)
		context:set_option(Ascii_mode,true)
	else
	end 
end 

--if context:is_composing() and  [,/. ] then
local function  commit_chk(char,env) 
	local context=env.engine.context

	if not context:is_composing()  then return false end  
	if char:match([[^[, ]$]]  ) then  return true
	elseif  char == "."  and not context:has_menu() then return true
	else return false end  
end 
function commit_input(env)
	local context=env.engine.context
	local cand= context:get_selected_candidate()
	context.input = (cand and cand.text ) or context.input  -- 更新 context.input
	context:commit() 
end 

local function complate_text(env) 
	local context=env.engine.context
	local seg=context.composition:back()
	log.info( string.format( "--complate start has_menu:%s  menu_count: %s, select_index: %s", 
	context:has_menu(), seg.menu:candidate_count() ,seg.selected_index ) ) 
	if not seg then return  end 

	-- 在 intput 字串 有 "/"  補齊 wildfmt 如 auto/i  --> auto*ing  
	if  context.input:match("/") then -- and backup_input ~= word  then 
		local _ , word , part= dict.wildfmt(context.input)
		env.history_words:insert(context.input)

		part = ( part == ""  and  "" ) or  ":"  .. part
		log.info( string.format( "--complate   / :%s  menu_count: %s, select_index: %s", 
		context:has_menu(), seg.menu:candidate_count() ,seg.selected_index ) ) 
		context.input= word .. part
		return 
	end 

	-- 如果有 menu 以讀取 目前 select cand 補齊 input 
	if context:has_menu() then 
		local cand=seg:get_selected_candidate( )
		-- 如果 cand 是第一個 且 type== "pre_english" 重取下一個 cand 補齊  
		if  seg.selected_index == 0 and cand.type == Pre_english and seg.menu:candidate_count() >=1  then  
			cand= seg:get_candidate_at(seg.selected_index +1 ) 
		end 
		env.history_words:insert( context.input )
		log.info( string.format( "--complate has_menu  hasmenu :%s  menu_count: %s, select_index: %s", 
		context:has_menu(), seg.menu:candidate_count() ,seg.selected_index ) ) 
		context.input= cand.text
	end 
end 
local function restort_word(env) 
	local context=env.engine.context
	context.input=  env.history_words:remove()  or context.input 
end 
local function hot_keyword1(hotkey,env) 
	local context=env.engine.context
	local wildword_ = (env.keyname2[hotkey] and "*" ..  env.keyname2[hotkey] ) or "" 
	env.history_words:insert(context.input)
	context.input = context.input  .. wildword_ 
end 
local function hotkey_cmd(hotkey,env)
	local context= env.engine.context

	--  Tab    intput 補齊
	if  hotkey == "Tab" then  complate_text(env) ; return true end 
	-- 返迴 上一次 補齊的 context:input 
	if  hotkey == "Shift+Tab" or hotkey== "Shift_L+Tab" or hotkey== "Shift_R+Tab"  then 
		restort_word(env) 
		return true 
	end 
	--  字根補齊熱鍵 
	local hotkey_char= hotkey:match("^Control%+(%w)$") 
	local part_word= dict.part_word(  hotkey_char or "" ) 
	if part_word ~= "" then  context.input= context.input .. part_word ;  return true end 


	return false 
end 

local function lua_init()
	local dict= require("english/english_dict"):New() 
	local function processor_func(key,env) -- key:KeyEvent,env_
		local Rejected, Accepted, Noop = 0,1,2 
		local context=env.engine.context 
		local composition=context.composition
		local is_composing=context:is_composing()

		-- 任何模式下
		--  toggle mode    ascii - chinese  -- english -- ascii 
		if key:repr() == Toggle_key then  toggle_mode(env)   ; return Accepted  end 
		if key:repr() == Toggle_fold_key  then 
			context:set_option( Fold_sw , not context:get_option(Fold_sw) )
			return Accepted 
		end 
		--  english_mode 模式下
		--if (key:ctrl() or key:alt() or key:release() ) then return k.Noop end 
		if not  english_mode(env)  then return Noop end  
		-- english mode  pass  alt release 
		if ( key:alt() or key:release() ) then return Noop end 

		local keycode=key.keycode 
		local keyrepr=key:repr()
		local keychar= (keycode >=0x20 and keycode <0x80 and string.char(keycode) ) or ""

		-- context.input 有資料時 , 需要處理的keyevent
		if is_composing then 
			-- commit_char check 
			--  return true 表示 熱鍵接收
			if  commit_chk(keychar, env) then commit_input(env) return Rejected end  --  
			--  hotkey check  and update context.input 
			--  Tab ,Shift+Tab ctrl+a~z ( 補齊功能 返迴上一佪input 字根補齊）
			--  return true 表示 熱鍵接收
			if hotkey_cmd( keyrepr,env) then return Accepted end 
		else 
			--  在 not is_composing 時如果 第一字母為 pucnt  直接上屏
			if  keychar:match("[%p ]") then return Rejected end  
		end 
		--  在 english_mode 下 一般輸入模式
		-- ascii   a-z A-Z_?*.-  
		if  keychar:match([[^[%a%:/'?*_.-]$]]) then  
			context:push_input(keychar)
			return Accepted
		else 
			return Noop  
		end 
		return Noop  
	end  

	local function processor_init_func(env)
		env.history_words= setmetatable({} , {__index=table } ) 
		-- 註冊 commit_notifier 上屏後  清空 history_words 
		env.connection= env.engine.context.commit_notifier:connect(
		function(context)  
			env.history_words= setmetatable({} , {__index=table } ) 
		end )
		----LINE   --- function 引用 dict 需要再檢查 
	end 
	local function processor_fini_func(env)


		-- 移除註冊 commit_notifier 上屏後  清空 history_words 
		env.keyname=nil 
		env.connection:disconnect() 
	end 


	-- lua segmentor
	local function segmentor_func(segs ,env) -- segmetation:Segmentation,env_
		local context=env.engine.context
		local cartpos= segs:get_current_start_position()

		-- 在english_mode() 為 input 打上 english tag  
		if english_mode(env) and context:is_composing() then 
			local str = segs.input:sub(cartpos) 
			if not  str:match([[^%a[%a'?*_.-]*]]) then  return true  end 
			local str= segs.input:sub(segs:get_current_start_position() )
			local seg=Segment(cartpos,segs.input:len())
			seg.tags=  Set({English})
			seg.prompt="(english)"
			segs:add_segment(seg) 

			-- 終止 後面 segmentor   打tag
			return false 
		end 
		-- 不是 english_mode  pass 此 segmentor  由後面處理 
		return true
	end 

	local function segmentor_init_func(env)
	end 
	local function segmentor_fini_func(env)
	end 
	-- lua translator 
	local function translator_func(input,seg,env)  -- input:string, seg:Segment, env_

		local context=env.engine.context
		local fold_status=context:get_option( Fold_sw ) 
		--在  模式  和 tag 為 english 才 翻譯
		if english_mode(env) and seg:has_tag(English)  then 
			-- 為模擬 英文模式 將input 設第一個候選字 空白鍵 原碼+空白 上屏
			yield( Candidate(Pre_english , seg.start,seg._end , input  , "[english]"))
			for word_info in dict:iter(input) do 
				yield( Candidate(English, seg.start,seg._end , word_info.word, word_info.info ))
			end 
		end 
	end 

	local function translator_init_func(env)
	end 
	local function translator_fini_func(env)
	end 

	-- lua filter

	--  cand data to string 
	local function filter_func(input,env)  -- input:Tranlation , env_
		local context=env.engine.context

		for cand in  input:iter() do 

			if cand.type== English then  
				for word_info in env.info_iter(cand.comment,context.input) do
					yaild( Candidate( cand.type,cand.text,cand.start,cand._end,word_info.info) )
				end 
			elseif cand.type == Pre_english then yield(cand)   -- pass 
			else yield(cand) end  -- pass 
		end 
	end 

	local function filter_init_func(env) -- non return 
		env.info_mode=1
		env.info_iter= function (word_info,text)
			local  info_mode= env.engine.context:get_option(Fold_sw) 
			local  patternstr,wildstr,part= dict.Wildfmt(text) -- class method 
			local  tab=env.info_mode and word_info.info:split("\n") or {word_info.info:gsub("\n"," ") } 
			return coroutine.wrap(function()
				tab:each(function(elm) 
					if elm:match(part) then 
						coroutine.yield({word=word_info.word,info=elm}) 
					end 
				end )
			end)

		end 
		--env.connection= env.engine.context.commit_notifier:connect(
		--function(context)  local cand=env.cand
		--if english_mode(env) then 
		--end 
		--end )
	end 
	local function filter_fini_func(env)  -- non return 
		env.info_mode=nil
		env.info_iter=nil
		--env.connection:disconnect() 
	end 

	return { 
		processor= { func=processor_func, init=processor_init_func, fini=processor_fini_func} , 
		segmentor= { func= segmentor_func, init=segmentor_init_func , fini=segmentor_fini_func} , 
		translator={ func=translator_func, init=translator_init_func,fini=translator_fini_func} , 
		filter=    { func=filter_func, init=filter_init_func,    fini=filter_fini_func } ,   
	}

end 
-- init  lua component  to global variable
--[[
local function init(tagname, unload_)
	local tab_= lua_init() 
	for k,v in pairs( tab_) do 
		local kk= tagname .. "_" .. k 
		_G[kk] =  ( not unload_ and  v ) or nil  --  load and v    or  nil 
	end 


end 
--]]

return lua_init



