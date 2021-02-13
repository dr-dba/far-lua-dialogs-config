-- Dialog module

require("Lib-Common-@Xer0X")
require("introspection-@Xer0X")

-- allow only as module usage:
if not Xer0X.fnc_file_whoami({ ... }) then return end
-- #####

local Package = {}
--[[
local F = far.GetFlags() --]]
local F = far.Flags
local SendDlgMessage = far.SendDlgMessage
local bor = bit64.bor

--------------------------------------------------------------------------------
-- @param item : dialog item (a table)
-- @param ...  : sequence of item types, to check if `item' belongs to any of them
-- @return     : whether `item' belongs to one of the given types (a boolean)
--------------------------------------------------------------------------------

local function CheckItemType(item, ...)
  for i=1,select("#", ...) do
    local tp = select(i, ...)
    if tp==item[1] or F[tp]==item[1] then return true end
  end
  return false
end

-- Bind dialog item names (see struct FarDialogItem) to their indexes.
local item_map = {
  Type=1,
  X1=2,
  Y1=3,
  X2=4,
  Y2=5,
  Selected=6, ListItems=6, VBuf=6,
  History=7,
  Mask=8,
  Flags=9,
  Data=10,
  MaxLength=11,
  UserData=12
}

-- Metatable for dialog items. All writes and reads at keys contained
-- in item_map (see above) are redirected to corresponding indexes.
local item_meta = {
  __index    = function (self, key)
                 local ind = item_map[key]
                 return rawget (self, ind) or ind
               end,
  __newindex = function (self, key, val)
                 rawset (self, item_map[key] or key, val)
               end,
}

function item_map:GetCheckState (hDlg)
  return SendDlgMessage(hDlg,"DM_GETCHECK",self.id,0)
end

function item_map:GetCheck (hDlg)
  return (1 == self:GetCheckState(hDlg))
end

function item_map:SaveCheck (hDlg, tData)
  local v = self:GetCheckState(hDlg)
  tData[self.name] =
  	(v > 1) and v or (v == 1)
end

function item_map:SetCheck (hDlg, check)
  SendDlgMessage(hDlg, "DM_SETCHECK", self.id,
  	tonumber(check) or (check and 1) or 0)
end

function item_map:Enable (hDlg, enbl)
  SendDlgMessage(hDlg, "DM_ENABLE", self.id, enbl and 1 or 0)
end

function item_map:GetText (hDlg)
  return SendDlgMessage(hDlg, "DM_GETTEXT", self.id)
end

function item_map:SaveText (hDlg, tData)
  tData[self.name] = self:GetText(hDlg)
end

function item_map:SetText (hDlg, str)
  return SendDlgMessage(hDlg, "DM_SETTEXT", self.id, str)
end

function item_map:GetListCurPos (hDlg)
  local pos = SendDlgMessage(hDlg, "DM_LISTGETCURPOS", self.id, 0)
  return pos.SelectPos
end

function item_map:SetListCurPos (hDlg, pos)
  return SendDlgMessage(hDlg, "DM_LISTSETCURPOS", self.id, {SelectPos=pos})
end

-- A key for the "map" (an auxilliary table contained in a dialog table).
-- *  Both dialog and map tables contain all dialog items:
--    the dialog table is an array (for access by index by FAR API),
--    the map table is a dictionary (for access by name from Lua script).
-- *  A unique key is used, to prevent accidental collision with dialog
--    item names.
local mapkey = {}

-- Metatable for dialog.
-- *  When assigning an item to a (string) field of the dialog, the item is also
--    added to the array part.
-- *  Normally, give each item a unique name, though if 2 or more items do not
--    need be accessed by the program via their names, they can share the same
--    name, e.g. "sep" for separator, "lab" for label, or even "_".
local dialog_meta = {
  __newindex =
      function (self, item_name, item)
        item.name = item_name
        item.id = #self+1 --> id is 1-based
        setmetatable (item, item_meta)
        rawset (self, #self+1, item) -- table.insert (self, item)
        self[mapkey][item_name] = item
      end,

  __index = function (self, key) return rawget (self, mapkey)[key] end
}

-- Dialog constructor
local function NewDialog ()
  return setmetatable ({ [mapkey]={} }, dialog_meta)
end

local function
LoadData (aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautoload or item._noauto) then
      local v = aData[item.name]
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON")
      then
        item[6] = v==nil and (item[6] or 0) or
        	v==false and 0 or
        	tonumber(v) or
        	1
      elseif
      	CheckItemType(item, "DI_EDIT", "DI_FIXEDIT")
      then
        item[10] = v or item[10] or ""
      elseif
      	CheckItemType(item, "DI_LISTBOX", "DI_COMBOBOX")
      then
        if v and v.SelectIndex then
          item[6].SelectIndex = v.SelectIndex
        end
      end
    end
  end
end

local function
	SaveData (aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautosave or item._noauto) then
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON") then
        local v = item[6]
        aData[item.name] =
        	(v > 1) and v or (v == 1)
      elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT") then
        aData[item.name] = item[10]
      elseif CheckItemType(item, "DI_LISTBOX", "DI_COMBOBOX") then
        aData[item.name] = aData[item.name] or {}
        aData[item.name].SelectIndex =
        	item[6].SelectIndex
      end
    end
  end
end

local function
	LoadDataDyn (hDlg, aDialog, aData
		, aUseDefaults)
  for _,item in ipairs(aDialog) do
    if not (item._noautoload or item._noauto) then
      local name = item.name
      if
      	aData[name]~=nil
      	or item._default~=nil or aUseDefaults
      then
	-- highest priority
        local val = aData[name]
        -- middle priority
        if val==nil then val=item._default end
        if
        	CheckItemType(item, "DI_CHECKBOX"
        		)
        then
	-- lowest priority (default)
          aDialog[name]:SetCheck(hDlg
          	, val==nil and 0 or val)
        elseif
        	CheckItemType(item
        		, "DI_RADIOBUTTON")
        then
          if val then
          	aDialog[name]:SetCheck(hDlg
	          		, 1)
          end
        elseif CheckItemType(item, "DI_EDIT", "DI_FIXEDIT")
        then
        -- lowest priority (default)
          aDialog[name]:SetText(hDlg
          	, val==nil and "" or val)
        end
      end
    end
  end
end

local function
	SaveDataDyn (hDlg, aDialog, aData)
  for _,item in ipairs(aDialog) do
    if not (item._noautosave or item._noauto)
    then
      if CheckItemType(item, "DI_CHECKBOX", "DI_RADIOBUTTON")
      then
        aDialog[item.name]:SaveCheck(hDlg, aData)
      elseif
      	CheckItemType(item, "DI_EDIT", "DI_FIXEDIT")
      then
        aDialog[item.name]:SaveText(hDlg, aData)
      end
    end
  end
end

---- Started: [2020-08-15]
---- Replacement for far.Dialog() with much cleaner syntax of dialog description.
-- @param aData table : contains an array part ("items") and a dictionary part ("properties")

--    Supported properties for entire dialog (all are optional):
--        guid          : string   : a text-form guid
--        width         : number   : dialog width
--        help          : string   : help topic
--        flags         : flags    : dialog flags
--        proc          : function : dialog procedure

--    Supported properties for a dialog item (all are optional except tp):
--        tp            : string   : type; mandatory
--        text          : string   : text
--        name          : string   : used as a key in the output table
--        val           : number/boolean : value for element initialization
--        flags         : number   : flag or flags combination
--        hist          : string   : history name for DI_EDIT, DI_FIXEDIT
--        mask          : string   : mask value for DI_FIXEDIT, DI_TEXT, DI_VTEXT
--        x1            : number   : left position
--        x2            : number   : right position
--        y1            : number   : top position
--        y2            : number   : bottom position
--        ystep         : number   : vertical offset relative to the previous item; may be <= 0; default=1
--        list          : table    : mandatory for DI_COMBOBOX, DI_LISTBOX
--        buffer        : userdata : buffer for DI_USERCONTROL

--    Boolean flags properties:
--        boxcolor                    : DIF_BOXCOLOR
--        btnnoclose                  : DIF_BTNNOCLOSE
--        centergroup                 : DIF_CENTERGROUP
--        centertext                  : DIF_CENTERTEXT
--        defaultbutton (or default)  : DIF_DEFAULTBUTTON
--        disable                     : DIF_DISABLE
--        dropdownlist                : DIF_DROPDOWNLIST
--        editexpand                  : DIF_EDITEXPAND
--        editor                      : DIF_EDITOR
--        editpath                    : DIF_EDITPATH
--        editpathexec                : DIF_EDITPATHEXEC
--        focus                       : DIF_FOCUS
--        group                       : DIF_GROUP
--        hidden                      : DIF_HIDDEN
--        lefttext                    : DIF_LEFTTEXT
--        listautohighlight           : DIF_LISTAUTOHIGHLIGHT
--        listnoampersand             : DIF_LISTNOAMPERSAND
--        listnobox                   : DIF_LISTNOBOX
--        listnoclose                 : DIF_LISTNOCLOSE
--        listtrackmouse              : DIF_LISTTRACKMOUSE
--        listtrackmouseinfocus       : DIF_LISTTRACKMOUSEINFOCUS
--        listwrapmode                : DIF_LISTWRAPMODE
--        manualaddhistory            : DIF_MANUALADDHISTORY
--        moveselect                  : DIF_MOVESELECT
--        noautocomplete              : DIF_NOAUTOCOMPLETE
--        nobrackets                  : DIF_NOBRACKETS
--        nofocus                     : DIF_NOFOCUS
--        readonly                    : DIF_READONLY
--        righttext                   : DIF_RIGHTTEXT
--        selectonentry               : DIF_SELECTONENTRY
--        setshield                   : DIF_SETSHIELD
--        showampersand               : DIF_SHOWAMPERSAND
--        tristate                    : DIF_3STATE
--        uselasthistory              : DIF_USELASTHISTORY
--        wordwrap                    : DIF_WORDWRAP

-- @return1 out  table : contains final values of dialog items indexed by 'name' field of 'aData' items
-- @return2 pos number : return value of API far.Dialog()
----------------------------------------------------------------------------------------------------
local function SimpleDialog (aData)
  assert(type(aData)=="table", "parameter 'Data' must be a table")
  local guid = win.Uuid(aData.guid or "00000000-0000-0000-0000-000000000000")
  local W = aData.width or 76
  local Y, H = 0, 0
  local arr = {}
  for i,v in ipairs(aData) do
    local tp = v.tp
    local text = v.text or ""
    local hist = v.hist or ""
    local mask = v.mask or ""
    local x1 = v.x1 or 5
    local x2 = v.x2 or W-6
    Y = Y + (v.ystep or 1)
    local y1 = v.y1 or Y
    local y2 = v.y2 or Y
    Y = math.max(Y, y1, y2)
    H = math.max(H, Y)
    local flags = v.flags or 0
    assert(type(flags)=="number", "type of 'flags' is not a number")
    if v.boxcolor                    then flags = bor(flags, F.DIF_BOXCOLOR);              end
    if v.btnnoclose                  then flags = bor(flags, F.DIF_BTNNOCLOSE);            end
    if v.centergroup                 then flags = bor(flags, F.DIF_CENTERGROUP);           end
    if v.centertext                  then flags = bor(flags, F.DIF_CENTERTEXT);            end
    if v.defaultbutton or v.default  then flags = bor(flags, F.DIF_DEFAULTBUTTON);         end -- !!!
    if v.disable                     then flags = bor(flags, F.DIF_DISABLE);               end
    if v.dropdownlist                then flags = bor(flags, F.DIF_DROPDOWNLIST);          end
    if v.editexpand                  then flags = bor(flags, F.DIF_EDITEXPAND);            end
    if v.editor                      then flags = bor(flags, F.DIF_EDITOR);                end
    if v.editpath                    then flags = bor(flags, F.DIF_EDITPATH);              end
    if v.editpathexec                then flags = bor(flags, F.DIF_EDITPATHEXEC);          end
    if v.focus                       then flags = bor(flags, F.DIF_FOCUS);                 end
    if v.group                       then flags = bor(flags, F.DIF_GROUP);                 end
    if v.hidden                      then flags = bor(flags, F.DIF_HIDDEN);                end
    if v.lefttext                    then flags = bor(flags, F.DIF_LEFTTEXT);              end
    if v.listautohighlight           then flags = bor(flags, F.DIF_LISTAUTOHIGHLIGHT);     end
    if v.listnoampersand             then flags = bor(flags, F.DIF_LISTNOAMPERSAND);       end
    if v.listnobox                   then flags = bor(flags, F.DIF_LISTNOBOX);             end
    if v.listnoclose                 then flags = bor(flags, F.DIF_LISTNOCLOSE);           end
    if v.listtrackmouse              then flags = bor(flags, F.DIF_LISTTRACKMOUSE);        end
    if v.listtrackmouseinfocus       then flags = bor(flags, F.DIF_LISTTRACKMOUSEINFOCUS); end
    if v.listwrapmode                then flags = bor(flags, F.DIF_LISTWRAPMODE);          end
    if v.manualaddhistory            then flags = bor(flags, F.DIF_MANUALADDHISTORY);      end
    if v.moveselect                  then flags = bor(flags, F.DIF_MOVESELECT);            end
    if v.noautocomplete              then flags = bor(flags, F.DIF_NOAUTOCOMPLETE);        end
    if v.nobrackets                  then flags = bor(flags, F.DIF_NOBRACKETS);            end
    if v.nofocus                     then flags = bor(flags, F.DIF_NOFOCUS);               end
    if v.readonly                    then flags = bor(flags, F.DIF_READONLY);              end
    if v.righttext                   then flags = bor(flags, F.DIF_RIGHTTEXT);             end
    if v.selectonentry               then flags = bor(flags, F.DIF_SELECTONENTRY);         end
    if v.setshield                   then flags = bor(flags, F.DIF_SETSHIELD);             end
    if v.showampersand               then flags = bor(flags, F.DIF_SHOWAMPERSAND);         end
    if v.tristate                    then flags = bor(flags, F.DIF_3STATE);                end -- !!!
    if v.uselasthistory              then flags = bor(flags, F.DIF_USELASTHISTORY);        end
    if v.wordwrap                    then flags = bor(flags, F.DIF_WORDWRAP);              end
    if tp=="doublebox" or tp=="dblbox" or tp=="dbox" then
      if i == 1 then arr[i] = {F.DI_DOUBLEBOX,  3, y1,W-4,0,  0,0,0,flags,  text}
      else           arr[i] = {F.DI_DOUBLEBOX,  x1,y1,x2,y2,  0,0,0,flags,  text}
      end
    elseif tp=="singlebox" or tp=="sbox" then
      if i == 1 then arr[i] = {F.DI_SINGLEBOX,  3, y1,W-4,0,  0,0,0,flags,  text}
      else           arr[i] = {F.DI_SINGLEBOX,  x1,y1,x2,y2,  0,0,0,flags,  text}
      end
    elseif tp=="text" or tp=="txt" then
      arr[i] = {F.DI_TEXT,  x1,y1,x2,y1,  0,0,0,flags,  text}
    elseif tp=="vtext" or tp=="vtxt" then
      if v.mask then flags = bor(flags, F.DIF_SEPARATORUSER); end -- set the flag automatically
      arr[i] = {F.DI_VTEXT,  x1,y1,x1,y2,  0,0,mask,flags,  text}
    elseif tp=="separator" or tp=="separ" or tp=="sep" or
           tp=="separator2" or tp=="separ2" or tp=="sep2" then
      x1, x2 = v.x1 or -1, v.x2 or -1
      flags = bor(flags, tp:find("2") and F.DIF_SEPARATOR2 or F.DIF_SEPARATOR)
      if v.mask then flags = bor(flags, F.DIF_SEPARATORUSER); end -- set the flag automatically
      arr[i] = {F.DI_TEXT,  x1,y1,x2,y1,  0,0,mask,flags,  text}
    elseif tp=="edit" then
      if v.hist then flags = bor(flags, F.DIF_HISTORY); end -- set the flag automatically
      arr[i] = {F.DI_EDIT,  x1,y1,x2,0,  0,hist,0,flags,  text}
    elseif tp=="fixedit" then
      if v.hist then flags = bor(flags, F.DIF_HISTORY);  end -- set the flag automatically
      if v.mask then flags = bor(flags, F.DIF_MASKEDIT); end -- set the flag automatically
      arr[i] = {F.DI_FIXEDIT,  x1,y1,v.x2 or x1,0,  0,hist,mask,flags,  text}
    elseif tp=="pswedit" then
      arr[i] = {F.DI_PSWEDIT,  x1,y1,x2,0,  0,"",0,flags,  text}
    elseif tp=="checkbox" or tp=="chbox" or tp=="cbox" then
      local val = (v.val==2 and 2) or (v.val and v.val~=0 and 1) or 0
      arr[i] = {F.DI_CHECKBOX,  x1,y1,0,y1,  val,0,0,flags,  text}
    elseif tp=="radiobutton" or tp=="rbutton" or tp=="rbutt"  or tp=="rbut" or tp=="rbtn" then
      arr[i] = {F.DI_RADIOBUTTON,  x1,y1,0,y1,  v.val and 1 or 0,0,0,flags,  text}
    elseif tp=="button" or tp=="butt" or tp=="but" or tp=="btn" then
      arr[i] = {F.DI_BUTTON,  x1,y1,0,y1,  0,0,0,flags,  text}
    elseif tp=="combobox" then
      assert(type(v.list)=="table", "\"list\" field must be a table")
      arr[i] = {F.DI_COMBOBOX,  x1,y1,x2,y1,  v.list,0,0,flags,  text}
    elseif tp=="listbox" then
      assert(type(v.list)=="table", "\"list\" field must be a table")
      arr[i] = {F.DI_LISTBOX,  x1,y1,x2,y2,  v.list,0,0,flags,  text}
    elseif tp=="usercontrol" or tp=="user" then
      local buffer = v.buffer or 0
      arr[i] = {F.DI_USERCONTROL,  x1,y1,x2,y2,  buffer,0,0,flags,  text}
    else
      error("Unsupported dialog item type: "..tostring(v.tp))
    end
  end
  if arr[1][1] == F.DI_DOUBLEBOX or arr[1][1] == F.DI_SINGLEBOX then
    H = H + 3
    arr[1][5] = H - 2
  else
    H = H + 2
  end
  local ret = far.Dialog(guid, -1,-1,W,H, aData.help, arr, aData.flags, aData.proc)
  if ret >= 1 and not aData[ret].cancel then --TODO: document this invented "cancel" flag
    local out = {}
    for i,v in ipairs(aData) do
      if type(v.name) == "string" then
        local w = arr[i]
        if w[1]==F.DI_CHECKBOX then
          out[v.name] = (w[6]==2) and 2 or (w[6] ~= 0) -- false,true,2
        elseif w[1]==F.DI_RADIOBUTTON then
          out[v.name] = (w[6] ~= 0) -- boolean
        elseif w[1]==F.DI_EDIT or w[1]==F.DI_FIXEDIT or w[1]==F.DI_PSWEDIT then
          out[v.name] = w[10] -- string
        elseif (w[1]==F.DI_COMBOBOX or w[1]==F.DI_LISTBOX) and type(w[6])=="table" then
          out[v.name] = w[6].SelectIndex -- number
        end
      end
    end
    return out, ret
  end
  return nil
end

return {
  CheckItemType = CheckItemType,
  NewDialog = NewDialog,
  LoadData = LoadData,
  SaveData = SaveData,
  LoadDataDyn = LoadDataDyn,
  SaveDataDyn = SaveDataDyn,
  SimpleDialog = SimpleDialog,
}

--[[ Adding item example:
dlg = dialog.NewDialog()
dlg.cbxCase = {
	"DI_CHECKBOX",
	10,4,0,0,  0,
	"","",0,
	"&Case sensitive"
}
--]]
