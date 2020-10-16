
USERDIR= ( USERDIR or  os.getenv("APPDATA") or "" ) .. [[\Rime]]
-- require("english")(tagname)  --設定 lua tagname 井 建立 全域變數  english_processor english_segmentor ...
-- require("english") -- lua/english/init.lua 
require("english")("english") 

--local english = require("english")()
--english_processor = english.processor
--english_segmentor = english.segmentor
--english_translator = english.translator
--english_filter = english.filter
