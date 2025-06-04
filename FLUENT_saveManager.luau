local httpService = game:GetService("HttpService")


type Dropdown = {Value: any, Values: {i: any}, Multi: boolean, Displayer: (v) -> (n)?, SetValue: (any) -> ()}

local DisplayerParser = {
	Encode = function(Value)
		local Encoded = {}

		for Val: any, Bool: boolean in Value do
			table.insert(Encoded, Val)
		end

		return Encoded
	end,
}

local function TableEqual(Table, Reflect)
	for Index, Value in Table do 
		if Reflect[Index] ~= Value then return false end 
	end 

	return true
end  

local function SetDisplayerDropdownValue(Dropdown: Dropdown, Value)
	if Dropdown.Multi then
		local Values = {}
		
		for _, DataValue in Value do 
			for _, DropdownValue in Dropdown.Values do 
				if typeof(DropdownValue) ~= 'table' or not TableEqual(DataValue, DropdownValue) then continue end 
				
				Values[DropdownValue] = true
				break
			end
		end
		
		Dropdown:SetValue(Values)
	else
		for _, DropdownValue in Dropdown.Values do 
			if typeof(DropdownValue) ~= 'table' or not TableEqual(Value, DropdownValue) then continue end 
			
			Dropdown:SetValue(DropdownValue)
			break
		end	
	end
end

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager.Options, SaveManager.Library = {} :: { [string]: {Type: string, Value: any, SetValues: (self: any, NewValue: { [any]: any }) -> nil, SetValue: (self: any, NewValue: any, ...any) -> nil, SetValueRGB: (self: any, NewValue: Color3, Transparency: number?) -> nil} }, {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = "Toggle", idx = idx, value = object.Value, Timestamp = object.Instance.CreatedAt } 
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = "Slider", idx = idx, value = object.Value, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				local HasDisplayer = object.CustomDisplayer
				
				return { type = "Dropdown", idx = idx, value = (HasDisplayer and object.Multi and DisplayerParser.Encode(object.Value) or object.Value), mutli = object.Multi, Timestamp = object.Instance.CreatedAt, displayer = HasDisplayer}
			end,
			Load = function(idx, data)
				if data.value == nil then return end
				
				local DropdownElement = SaveManager.Options[idx]
				if not DropdownElement then return end
				
				local Value = data.value 
				if typeof(Value) ~= 'table' or (not data.displayer) then
					DropdownElement:SetValue(Value)
					return
				end
				
				SetDisplayerDropdownValue(DropdownElement, Value)
			end,
		},
		Colorpicker = {
			Save = function(idx, object)
				return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Keybind = {
			Save = function(idx, object)
				return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = "Input", idx = idx, text = object.Value, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					SaveManager.Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function SaveManager:Save(name): (boolean, string?)
		if (not name) then
			return false, "No config file is selected"
		end

		local fullPath = `{self.Folder}/{name}.json`

		local data = {
			objects = {}
		}

		for idx, option in next, SaveManager.Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			data.objects[#data.objects + 1] = self.Parser[option.Type].Save(idx, option)
		end

		table.sort(data.objects, function(v1: { Timestamp: number }, v2: { Timestamp: number })
			return v1.Timestamp < v2.Timestamp
		end)

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "Failed to JSON-Encode data"
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name): (boolean, string?)
		if (not name) then
			return false, "No config file is selected"
		end

		local file = `{self.Folder}/{name}.json`
		if not isfile(file) then return false, "invalid file" end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, "decode error" end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(self.Library.SafeCallback, self.Library, self.Parser[option.type].Load, option.idx, option)
			end
		end

		self.Library:SetTheme(self.Library.Theme)

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"InterfaceManager_InterfaceTheme", "InterfaceManager_AcrylicToggle", "InterfaceManager_TransparentToggle", "InterfaceManager_MenuKeybind"
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options
	end
end

return SaveManager
