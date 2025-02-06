term.clear();

local RECEIVE_FROM_MAIN_PROTO, SEND_TO_MAIN_PROTO = "AE_STORAGE_LOAD", "AE_STORAGE_LOAD_RESPONSE";

local bridge = peripheral.find("meBridge") or error("No meBridge found!", 0);
local modemCheck = peripheral.find("modem") or error("No modem found!", 0);
peripheral.find("modem", rednet.open)

local screenW, screenH = term.getSize()


function saveMasterData(id, proto, guiOn)
	  file=io.open("ae_master_data","w")
	  data = textutils.serialize({ ["master_id"] = id, ["proto"] = proto, ["guiOn"] = guiOn })
	  file:write(data)
	file:close()
end
function retreiveMasterData()
	local file = io.open("ae_master_data", "r")

	local data
	if file == nil then
		term.setCursorPos(1,1)
		term.write("no data about master node")
		term.setCursorPos(1,2)
		term.write("do one broadcast request to save master data")
		return -1
	else
		data=file:read("*a")
		file:close()
	end
	return textutils.unserialize(data)
end

local guiOn = true
-- (function() {

-- })()

function renderDate(periph)
	local w, h = periph.getSize()
	periph.setCursorPos(w-12, 1)
	local utc_offset = 3 * 60 * 60 - (46)
	local current_time = os.time(os.date("!*t"))
	local time = os.date('!%H:%M:%S', current_time+utc_offset)
	periph.setTextColor(colors.lightGray)
	periph.write("upd: "..time)
	periph.setTextColor(colors.white)
  end
function gatherAndSendData(pid, proto)
	local resultData;
	local totalCellStorage = bridge.getTotalItemStorage();
	local usedCellStorage = bridge.getUsedItemStorage();

	-- -- 
	-- term.setCursorPos(1, 10)
	-- term.write(usedCellStorage.." "..totalCellStorage)
	-- -- 

	-- после переклейки вылазит эта ошибка и не бутается сервак
	if usedCellStorage == nil or totalCellStorage == nil then
		term.clear()
		term.setCursorPos(1, 1)
		term.write("No "..((usedCellStorage == nil and "usedCellStorage") or "totalCellStorage"))
		sleep(5)
		os.reboot()
	end

	local availableCellStorage = bridge.getAvailableItemStorage();
	local usedPersentage = usedCellStorage * 100 / totalCellStorage;
	resultData = usedCellStorage .. "/" .. totalCellStorage .. " (" .. (function() if tostring(usedPersentage) == 'nan' then return "0.0" else return string.format("%.1f", usedPersentage) end end)() .. "%)" .. "|" .. usedCellStorage .. "," .. totalCellStorage;
	
	if guiOn == true then
		local displayData = resultData:match("^(.-)|")
		term.setCursorPos(1, 2);
		term.clearLine()
		-- term.write("node id: #"..os.getComputerID()..", node data: " .. displayData);
		term.write("node id:")
		term.setCursorPos(10, 2);
		local nodeId = os.getComputerID()
		local nodeIdString = "#"..nodeId
		term.blit(nodeIdString, string.rep("b", string.len(nodeIdString)), string.rep("f", string.len(nodeIdString)))
	
		term.setCursorPos(1, 3);
		term.clearLine()
		term.write("node data:")
	
		local inputPersentage = tonumber(displayData:match("%(([%d%.]+)%%%)"))
		
		function getProperColor(pers)
			local pc
			if pers < 1 then pc = "7"
			elseif pers > 1 and pers <= 30 then pc = "5"
			elseif pers > 30 and pers <= 45 then pc = "d"
			elseif pers > 40 and pers <= 65 then pc = "4"
			elseif pers > 65 and pers <= 85 then pc = "4"
			elseif pers > 85 and pers <= 95 then pc = "1"
			elseif pers > 95 and pers < 100 then pc = "e"
			elseif pers == 100 then pc = "c" end
			return pc
		end
		local persentageColor = getProperColor(inputPersentage)
	
		term.setCursorPos(12, 3);
		term.blit(displayData, string.rep(persentageColor, string.len(displayData)), string.rep("f", string.len(displayData)))
	
		-- term.write("sent data to #" .. pcID .. " using code " .. proto);
		term.setCursorPos(1, 5);
		term.clearLine()
		term.write("master node:")
		local masterNodeIdString = "#"..pid
		term.setCursorPos(14, 5);
		term.blit(masterNodeIdString, string.rep("a", string.len(masterNodeIdString)), string.rep("f", string.len(masterNodeIdString)))
	
		term.setCursorPos(1, 6);
		term.clearLine()
		term.write("protocol code:")
		term.setCursorPos(16, 6);
		term.blit(proto, string.rep("1", string.len(proto)), string.rep("f", string.len(proto)))
	
		term.setCursorPos(1,1)
		term.clearLine() -- если после "no data about master" будет запрос, то текст на первой строчке остаётся
	else
		term.clear()
	end

	renderDate(term)

	return resultData
end
function requestListener()
	local pcID, message, proto = rednet.receive(RECEIVE_FROM_MAIN_PROTO);
	saveMasterData(pcID, proto, guiOn)
	local data = gatherAndSendData(pcID, proto)
	rednet.send(pcID, data, SEND_TO_MAIN_PROTO);
end;

function renderOptions()
	term.setCursorPos(1, screenH-1)
	term.write(string.rep("-", screenW))
	term.setCursorPos(1, screenH)
	local optionsString = "Q-leave | U-manual update | G-gui switch"
	term.blit(optionsString, "b000000f0fa0000000f000000f0f80"..((guiOn and "ddd") or "eee").."f000000", string.rep("f", string.len(optionsString)))
end

quit = false;
function listenKeys()
	local event, param1 = os.pullEvent("char")
	
	if param1 == "q" then
		quit = true
	elseif param1 == "u" then
		local master_data_table = retreiveMasterData()
		if master_data_table == -1 then --если сервак только построен и не запускался
			return;
		else 
			local data = gatherAndSendData(master_data_table.master_id, master_data_table.proto)
			rednet.send(master_data_table.master_id, data, SEND_TO_MAIN_PROTO);
		end
	
	elseif param1 == "g" then
		guiOn = not guiOn
		
		local master_data_table = retreiveMasterData()
		if master_data_table == -1 then --если сервак только построен и не запускался
			return;
		else 
			saveMasterData(master_data_table.master_id, master_data_table.proto, guiOn)
			local data = gatherAndSendData(master_data_table.master_id, master_data_table.proto)
			rednet.send(master_data_table.master_id, data, SEND_TO_MAIN_PROTO);
		end
	end

	renderOptions()
end

(function()
	local master_data_table = retreiveMasterData()
	if master_data_table == -1 then --если сервак только построен и не запускался
		return;
	else 
		guiOn = master_data_table.guiOn
		gatherAndSendData(master_data_table.master_id, master_data_table.proto)
	end
	renderOptions()
end)()

while true do
	parallel.waitForAny(listenKeys, requestListener);
	if quit then
		print("Quitting....");
		sleep(0.001)
       	term.clear()
		break;
	end;
end;
