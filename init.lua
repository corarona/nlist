nlist = {}
local storage=minetest.get_mod_storage()
local sl="default"
local mode=1 --1:add, 2:remove
local nled_hud
local edmode_wason=false
nlist.selected=sl

local function get_dflist(list)
	local l
	for k,v in pairs(minetest.registered_chatcommands) do
		if v._list_setting and ( k == list or v._list_setting == list ) then
			l = v._list_setting
		end
		if l then return l end
	end
	return false
end

function nlist.add(list,node)
	if node == "" then mode=1 return end
	local tb=nlist.get(list)
	if table.indexof(tb,node) ~= -1 then return end
	table.insert(tb,node)
	nlist.set(list,tb)
	ws.dcm(node..' added to '..list)
end

function nlist.remove(list,node)
	if node == "" then mode=2 return end
	local tb=nlist.get(list)
	local ix = table.indexof(tb,node)
	if ix == -1 then return end
	table.remove(tb,ix)
	nlist.set(list,tb)
	ws.dcm(node..' removed from '..list)
end

function nlist.set(list,tb)
	local str=table.concat(tb,",")
	local df = get_dflist(list)
	if df then
		minetest.settings:set(df,str)
	else
		storage:set_string(list,str)
	end
end

function nlist.get(list)
	local str
	local df = get_dflist(list)
	if df then
		str=minetest.settings:get(df)
	else
		str=storage:get_string(list)
	end
	return str and str:split(',') or {}
end

function nlist.clear(list)
	local df = get_dflist(list)
	if df then
		minetest.settings:set(df,"")
	else
		storage:set_string(list,"")
	end
end

function nlist.select(list)
	sl = list
	nlist.selected = list
	local df = get_dflist(list)
	if df then
		sl = df
		nlist.selected = df
	end
end

function nlist.get_lists()
	local ret={}
	for name, _ in pairs(storage:to_table().fields) do
		table.insert(ret, name)
	end
	table.sort(ret)
	return ret
end

function nlist.rename(oldname, newname)
	oldname, newname = tostring(oldname), tostring(newname)
	local list = nlist.get(oldname)
	if not list or not nlist.set(newname,list) then return end
	if oldname ~= newname then
		 nlist.clear(oldname)
	end
	return true
end

function nlist.copy(oldname, newname)
	oldname, newname = tostring(oldname), tostring(newname)
	local list = nlist.get(oldname)
	if list then
		nlist.rename(oldname,oldname.."_backup")
	end
	if not list or not nlist.set(newname,list) then return end
	return true
end

function nlist.random(list)
	local str=storage:get(list)
	local tb=str:split(',')
	local kk = {}
	for k in pairs(tb) do
		table.insert(kk, k)
	end
	return tb[kk[math.random(#kk)]]
end

function nlist.show_list(list,hlp)
	if not list then return end
	local act="add"
	if mode == 2 then act="remove" end
	local txt=list .. "\n --\n" .. table.concat(nlist.get(list),"\n")
	local htxt="Nodelist edit mode\n .nla/.nlr to switch\n punch node to ".. act .. "\n.nlc to clear\n"
	if hlp then txt=htxt .. txt end
	nlist.set_nled_hud(txt)
end

function nlist.hide()
	if nled_hud then minetest.localplayer:hud_remove(nled_hud) nled_hud=nil end
end

function nlist.set_nled_hud(ttext)
	if not minetest.localplayer then return end
	if type(ttext) ~= "string" then return end

	local dtext ="List: ".. ttext

	if nled_hud then
		minetest.localplayer:hud_change(nled_hud,'text',dtext)
	else
		nled_hud = minetest.localplayer:hud_add({
			hud_elem_type = 'text',
			name		  = "Nodelist",
			text		  = dtext,
			number		= 0x00ff00,
			direction   = 0,
			position = {x=0.8,y=0.40},
			alignment ={x=1,y=1},
			offset = {x=0, y=0}
		})
	end
	return true
end

minetest.register_on_punchnode(function(p, n)
	if not minetest.settings:get_bool('nlist_edmode') then return end
	if mode == 1 then
		nlist.add(nlist.selected,n.name)
	elseif mode ==2 then
		nlist.remove(nlist.selected,n.name)
	end
end)

ws.rg('NlEdMode','nList','nlist_edmode', function()nlist.show_list(sl,true) end,function() end,function()nlist.hide() end)

minetest.register_chatcommand('nls',{
	description = "Select a list",
	params = "<list>",
	func=function(list)
		nlist.select(list)
	end
})
minetest.register_chatcommand('nlshow',{
	description = "Show a list without selecting",
	params = "<list>",
	func=function() nlist.show_list(sl) end
})
minetest.register_chatcommand('nlhide',{
	description = "Hide the currently shown list",
	params = "",
	func=function() nlist.hide() end
})
minetest.register_chatcommand('nla',{
	description = "Add an item to the selected list or switch to 'add' mode if run without parameters",
	params = "[<item>]",
	func=function(el) nlist.add(sl,el)  end
})
minetest.register_chatcommand('nlr',{
	description = "Remove an item from the selected list or switch to 'remove' mode if run without parameters",
	params = "[<item>]",
	func=function(el) nlist.remove(sl,el) end
})
minetest.register_chatcommand('nlc',{
	description = "Clear the selected list",
	params = "",
	func=function(el) nlist.clear(sl) end
})

minetest.register_chatcommand('nlawi',{
	description = "Add wielded itemstring to the selected list",
	params = "",
	func=function() nlist.add(sl,minetest.localplayer:get_wielded_item():get_name())  end
})

minetest.register_chatcommand('nlrwi',{
	description = "Remove wielded itemstring from the selected list",
	params = "",
	func=function() nlist.remove(sl,minetest.localplayer:get_wielded_item():get_name())  end
})

minetest.register_chatcommand('nlapn',{
	description = "Add pointed node's itemstring to the selected list",
	params = "",
	func=function()
		local ptd = minetest.get_pointed_thing()
		if ptd then
			local nd=minetest.get_node_or_nil(ptd.under)
			if nd then nlist.add(sl,nd.name) end
		end
end})
minetest.register_chatcommand('nlrpn',{
	description = "Remove pointed node's itemstring from the selected list",
	params = "",
	func=function()
		local ptd = minetest.get_pointed_thing()
		if ptd then
			local nd=minetest.get_node_or_nil(ptd.under)
			if nd then nlist.remove(sl,nd.name) end
		end
end})


for k,v in pairs(minetest.registered_chatcommands) do
	if v._list_setting then
		local oldfunc = v.func
		minetest.registered_chatcommands[k].params = "del <item> | add <item> | list | nls"
		minetest.registered_chatcommands[k].description = v.description..", nls to import currently selected nlist"
		minetest.registered_chatcommands[k].func = function(p)
			if p == "nls" then
				nlist.copy(nlist.selected,v._list_setting)
				return
			end
			return oldfunc(p)
		end
	end
end
