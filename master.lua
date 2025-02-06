term.clear()

local SEND_PROTO, RECEIVE_PROTO = "AE_STORAGE_LOAD", "AE_STORAGE_LOAD_RESPONSE"

local modemCheck = peripheral.find("modem") or error("No modem found!", 0);
peripheral.find("modem", rednet.open)
local chatbox = peripheral.find("chatBox") or error("No chatbox found!", 0);

local screenW, screenH = term.getSize()
local rowsDisplayScreenHeight = screenH-7-2

local presetNodesConfigured = 32

local respondedNodeCount = 0
local respondedNodeIDS = {}

local nodesDataScrollDelta = 0
local aeBytesDataOffset = 4

local loadAttempt = 0

local guiOn = true
local masterMode = 1 -- 1. retreive on redstone pulse, 2. ping by timer, 3.listen to command and chat back

local quit = false

-- связанное с chatbox
local timerID = nil
local currentUsername = nil
local commandMessage = nil

function requestSender()
  os.pullEvent("redstone") data = redstone.getInput("right")

  if data == false then
    return
  else  
    respondedNodeCount = 0
    respondedNodeIDS = {}
    rednet.broadcast(math.random(-130, 2500), SEND_PROTO)
  end

end

function getNodesDataTable()
  local file = io.open("ae_nodes_data", "r")
  local data
  
  if file == nil then 
    file=io.open("ae_nodes_data","w")
    data = textutils.serialize({})
    file:write(data)
  else
    data=file:read("*a")
  end
  file:close()
  return textutils.unserialize(data)
end

function checkSizeFormat(size)
  size = tonumber(size)
  local kbThreshold = 1024
  local mbThreshold = 1024 * kbThreshold
  local gbThreshold = 1024 * mbThreshold

  local unit = ""
  local formattedValue = size

  if size < kbThreshold then
    unit = "B"
  elseif size < mbThreshold then
    unit = "kB"
      formattedValue = size / kbThreshold
  elseif size < gbThreshold then
    unit = "mB"
      formattedValue = size / mbThreshold
  else
    unit = "gB"
      formattedValue = size / gbThreshold
  end

  return (string.format("%.1f", formattedValue))..unit
end

function renderDate(periph)
  periph.setCursorPos(screenW-12, 1)
  local utc_offset = 3 * 60 * 60 - (46)
  local current_time = os.time(os.date("!*t"))
  local time = os.date('!%H:%M:%S', current_time+utc_offset)
  periph.setTextColor(colors.lightGray)
	periph.write("upd: "..time)
	periph.setTextColor(colors.white)
end

function getProperColor(pers, jcolors)
  local jsonColors = {
    ["7"] = "dark_gray",
    ["5"] = "green",
    ["d"] = "dark_green",
    ["0"] = "white",
    ["4"] = "yellow",
    ["1"] = "gold",
    ["e"] = "red",
    ["c"] = "dark_red"
  }
  
  local pc
  if pers < 1 then pc = "7"
  elseif pers > 1 and pers <= 30 then pc = "5"
  elseif pers > 30 and pers <= 45 then pc = "d"
  elseif pers > 40 and pers <= 65 then pc = "0"
  elseif pers > 65 and pers <= 85 then pc = "4"
  elseif pers > 85 and pers <= 95 then pc = "1"
  elseif pers > 95 and pers < 100 then pc = "e"
  elseif pers == 100 then pc = "c" end

  if jcolors == true then 
    return jsonColors[pc]
  else
    return pc
  end
end

function writeDataToTerm(t, periph)
  local totalClusterUsed, totalClusterMax = 0, 0
  
  -- сначала идёт рассчёт таблицы и рендер

  local nodesTable = {}

  for key, fullfilmentString in pairs(t) do
    local usedCellInNode, totalCellInNode = fullfilmentString:match("|(%d+),(%d+)")
    totalClusterUsed = totalClusterUsed + tonumber(usedCellInNode)
    totalClusterMax = totalClusterMax + tonumber(totalCellInNode)

    -- отрисовка процент загрузки дисков, цветная
    local aeBytesString = usedCellInNode.."/"..totalCellInNode
    local aeBytesStringLength = string.len(aeBytesString)
    if aeBytesStringLength > aeBytesDataOffset then
      aeBytesDataOffset = aeBytesStringLength
    end

    nodesTable[key] = aeBytesString
  end


  if guiOn == true then
    periph.setCursorPos(14+aeBytesDataOffset,6)
    periph.clearLine()
    periph.write("| % load")

    periph.setCursorPos(1,6)
    periph.write("row | id | bytes")

    local index, startIndex = 8, 8
  
    for ti = 8, 17 do 
      term.setCursorPos(1, ti)
      term.clearLine()
    end

    local fromIndexIncl, toIndexIncl = nodesDataScrollDelta*-1+1, nodesDataScrollDelta*-1 + rowsDisplayScreenHeight
    -- 
    function sliceTableByPosition(inputTable, start, finish)
      local slicedTable = {}
      local keys = {}
      
      -- Collect keys and sort them
      for key in pairs(inputTable) do
          table.insert(keys, key)
      end
      table.sort(keys)
      
      -- Slice the table based on positions
      for i = start, math.min(finish, #keys) do
          local key = keys[i]
          slicedTable[key] = inputTable[key]
      end
      
      return slicedTable
    end
    -- 

    for key, fullfilmentString in pairs(sliceTableByPosition(t, fromIndexIncl, toIndexIncl)) do
      local aeBytesString = nodesTable[key]
      
      periph.setCursorPos(2,index+nodesDataScrollDelta)

      -- отрисовка номера ряда
      periph.write(index + (1-startIndex)..".")

      -- отрисовка #id ноды
      periph.setCursorPos(7,index+nodesDataScrollDelta)
      periph.write("#"..key)

      -- отрисовка байт/байт
      periph.setCursorPos(12,index+nodesDataScrollDelta)
      periph.write(aeBytesString)

      local inputPersentageString = fullfilmentString:match("%(([%d%.]+)%%%)")
      local inputPersentage = tonumber(fullfilmentString:match("%(([%d%.]+)%%%)"))
    
      
      local persentageColor = getProperColor(inputPersentage)

      local resultPersentageString = "("..inputPersentageString.."%)"
      local resultPersentageStringTextColor = "0"..string.rep(persentageColor, string.len(inputPersentageString))..persentageColor.."0"
      local resultPersentageStringBackgroundColor = string.rep("f", string.len(resultPersentageString))
      
      periph.setCursorPos(16+aeBytesDataOffset,index+nodesDataScrollDelta)
      periph.blit(resultPersentageString, resultPersentageStringTextColor , resultPersentageStringBackgroundColor)

      -- увеличение индекса вниз
      index = index + 1
    end

    term.setCursorPos(1, 7)
    term.write(string.rep("-", screenW))
    

    -- потом идёт рендер верхней колонки с суммарностью.
    periph.setCursorPos(1,1)
    periph.clearLine()
    periph.write("-----------")

    periph.setCursorPos(1,2)
    periph.clearLine()
    periph.setTextColor(colors.green)
    periph.write("Used bytes: "..totalClusterUsed.."("..checkSizeFormat(totalClusterUsed)..")")
    periph.setCursorPos(1,3)
    periph.clearLine()
    periph.setTextColor(colors.blue)
    periph.write("Total max bytes: "..totalClusterMax.."("..checkSizeFormat(totalClusterMax)..")")
    periph.setCursorPos(1,4)
    periph.clearLine()
    periph.setTextColor(colors.magenta)
    periph.write("Nodes responded: "..respondedNodeCount..' /'..presetNodesConfigured)

    periph.setTextColor(colors.white)
    periph.setCursorPos(1,5)
    periph.clearLine()
    periph.write("-----------")
  else 
    term.clear()
  end

  return totalClusterUsed, totalClusterMax
end

function checkUnrespondedNodes(actualTable, keysArr) 

  for actualTableKey, _ in pairs(actualTable) do
    if keysArr[actualTableKey] then
      goto continue
    else 
      actualTable[actualTableKey] = nil
    end
    ::continue::
  end

  return actualTable
end

function saveOptions(guiOn, masterMode) 
  local file = io.open("ae_master_options", "w+")
  file:write(textutils.serialize({ ["guiOn"] = guiOn, ["masterMode"] = masterMode }))
  file:close()
end
function retreiveOptions()
  local file = io.open("ae_master_options", "r")
  local data
  
  if file == nil then 
    file=io.open("ae_master_options","w")
    data = textutils.serialize({ ["guiOn"] = true, ["masterMode"] = 1 })
    file:write(data)
  else
    data=file:read("*a")
  end
  file:close()
  return textutils.unserialize(data)
end

function saveNodesData(t)
  local tableSerialized = textutils.serialize(t)
  local file = io.open("ae_nodes_data", "w+")
  file:write(tableSerialized)
  file:close()
end

function renderOptions()
  term.setCursorPos(1, screenH-1)
	term.write(string.rep("-", screenW))
	term.setCursorPos(1, screenH)

  local optionsString = "Q-leave | U-manual update | G-gui switch"
	term.blit(optionsString, "b000000f0fa0000000f000000f0f80"..((guiOn and "ddd") or "eee").."f000000", string.rep("f", string.len(optionsString)))
end
local c = 0
function readSavedData(periph)
  local table = getNodesDataTable()

  local keysLength = 0
  for k,v in pairs(table) do
    keysLength = keysLength + 1
  end
  respondedNodeCount = keysLength

  local tu, tm = writeDataToTerm(table, periph)

  periph.setCursorPos(screenW-15, 1)
  periph.write("loaded from save")

  renderOptions()
  return tu, tm
end

function serverFulfillmentDataResponse()
  local nodeId, fulfillment, proto = rednet.receive(RECEIVE_PROTO)
  
  loadAttempt = 0
  respondedNodeCount = respondedNodeCount + 1 
  nodeId = tostring(nodeId)
  respondedNodeIDS[nodeId] = nodeId

  local tableRetreived = getNodesDataTable()
  
  tableRetreived[nodeId] = fulfillment

  local tableUpdated = checkUnrespondedNodes(tableRetreived, respondedNodeIDS)

  -- рендер в терминале
  writeDataToTerm(tableUpdated, term)

  renderDate(term)
  renderOptions()

  saveNodesData(tableUpdated)
end

-- вызов один раз чтобы отрендерить после бута
  local options = retreiveOptions()
  guiOn, masterMode = options.guiOn, options.masterMode
  readSavedData(term)

function listenKeys()
  local event, param1 = os.pullEvent("char")

  if param1 == "q" then
    quit = true
  elseif param1 == "u" then
    loadAttempt = loadAttempt + 1

    local attemptString = "fetch attempt: "..loadAttempt
    term.setCursorPos(screenW-string.len(attemptString)+1, 1)
    term.setTextColor(colors.white)
    term.write(attemptString)

    respondedNodeCount = 0
    respondedNodeIDS = {}
    rednet.broadcast(math.random(-130, 2500), SEND_PROTO)

  -- elseif param1 == 'y' then
  --   if nodesDataScrollDelta == 0 then
  --     return
  --   else
  --     nodesDataScrollDelta = nodesDataScrollDelta - 1
  --   end
  --   readSavedData(term)
  -- elseif param1 == 'h' then
  --   if nodesDataScrollDelta < respondedNodeCount and respondedNodeCount > rowsDisplayScreenHeight then
  --     nodesDataScrollDelta = nodesDataScrollDelta + 1
  --   else
  --     return
  --   end
  --   readSavedData(term)

  elseif param1 == "g" then
    guiOn = not guiOn
    saveOptions(guiOn, masterMode)

    if guiOn == false then
      term.clear()
      renderOptions()
    else 
      readSavedData(term)
    end

    loadAttempt = loadAttempt + 1
    
    local attemptString = "fetch attempt: "..loadAttempt
    term.setCursorPos(screenW-string.len(attemptString)+1, 1)
    term.setTextColor(colors.white)
    term.write(attemptString)

    respondedNodeCount = 0
    respondedNodeIDS = {}
    rednet.broadcast(math.random(-130, 2500), SEND_PROTO)
  end
end

local messagePrefix = table.pack(" &7--- &5AE: &7Cluster &7Load &7 (global chat) --- ", "[]", "&7")
function chatboxTimerResponder()
    local event, eventTimerID = os.pullEvent("timer")
    if eventTimerID == timerID then
      local tClUsed, tClMax = readSavedData(term)
      local tClUsedFormatted = checkSizeFormat(tClUsed)
      local tClMaxFormatted = checkSizeFormat(tClMax)
      local persentageLoadTotal
      if tClUsed == 0 and tClMax == 0 then --небольшой фикс
        persentageLoadTotal = 0
      else
        persentageLoadTotal = string.format("%.2f", (tClUsed/tClMax)*100)
      end 
      local persentageLoadTotalColor = getProperColor(tonumber(persentageLoadTotal), true)
  
  
      if commandMessage == "aect" then
        local toastTitle = {{ text = "Main AE cluster load ".." ("..persentageLoadTotal.."%)", color = "white" }}
        local toastMessage = {
          {text="\n "},
          { text = tClUsedFormatted, color = "green", underlined = false },
          { text = "/", color = "white" },
          { text = tClMaxFormatted, color = "light_purple" },
          { text = " ("..persentageLoadTotal.."%) ", color = persentageLoadTotalColor, underlined = false },
          { text = "\n\n" },
          { text = "Total used bytes: ", color = "white", underlined = false },
          { text = tostring(tClUsed).." B ", underlined = false, color = "blue" },
          { text = "("..tClUsedFormatted..")", underlined = true, color = "blue" },  
          { text = "\nTotal max bytes: ", color = "white", underlined = false },
          { text = tostring(tClMax).." B ", underlined = false, color = "light_purple" },
          { text = "("..tClMaxFormatted..")", underlined = true, color = "light_purple" },  
          { text = "\nResponded nodes: ", color = "white", underlined = false },
          { text = tostring(respondedNodeCount), underlined = false, color = "gray" },
        }
  
        -- лол, оказывается, что если длина строчки слишком длинная, то тоаст не появится и ошибки не напишется
        chatbox.sendFormattedToastToPlayer(textutils.serialiseJSON(toastMessage), textutils.serialiseJSON(toastTitle), currentUsername, " &7------ &5AE: &7Cluster &7Load &7------ ", "[]", "&7")
      else
        local chatMessage = {
          {text="\n "},
          { text = tClUsedFormatted, color = "green", underlined = false },
          { text = "/", color = "white" },
          { text = tClMaxFormatted, color = "light_purple" },
          { text = " ("..persentageLoadTotal.."%) ", color = persentageLoadTotalColor, underlined = false },
          { 
            -- text = "Full data (hover)",
            text = "(hover)",
            underlined = true,
            color = "white",
            hoverEvent = {
              action = "show_text",
              contents = {
                { text = "Total used bytes: ", color = "white", underlined = false },
                { text = tostring(tClUsed).." B ", underlined = false, color = "blue"
                },
                { text = "("..tClUsedFormatted..")", underlined = true, color = "blue"
                },
            
                { text = "\nTotal max bytes: ", color = "white", underlined = false},
                { text = tostring(tClMax).." B ", underlined = false, color = "light_purple"
                },
                { text = "("..tClMaxFormatted..")", underlined = true, color = "light_purple"
                },
            
                { text = "\nResponded nodes: ", color = "white", underlined = false},
                { text = tostring(respondedNodeCount), underlined = false, color = "gray"
                },
              }
            }
          },
          -- не работает
          -- {
          --   text  = "\n[ Press to get update ]", underlined = true, color = "green",
          --   clickEvent = {
          --     action = "run_command", value = "tellraw @a 'aec'"
          --   }
          -- }
        }

        
        
        if commandMessage == "aecg" then
          chatbox.sendFormattedMessage(textutils.serialiseJSON(chatMessage), table.unpack(messagePrefix))
        else
          chatbox.sendFormattedMessageToPlayer(textutils.serialiseJSON(chatMessage), currentUsername, table.unpack(messagePrefix))
        end
      end
    end
end

function chatboxHandler() 
  local event, username, message, uuid, isHidden = os.pullEvent("chat")
  currentUsername = username

  if message == "aec" or message == "aect" or message == "aecg" then
    commandMessage = message
    
    if message == "aecg" then
      chatbox.sendMessage("Fetching data... (wait 2s)", "&5AE&7:CL(gc)", "[]", "&7")
    elseif message == "aec" or message == "aect" then
      chatbox.sendMessageToPlayer("Fetching data... (wait 2s)", username, "&5AE&7:CL(lc)", "[]", "&7")
    end
    
    respondedNodeCount = 0
    respondedNodeIDS = {}
    rednet.broadcast(math.random(-130, 2500), SEND_PROTO)

    timerID = os.startTimer(2)
  end
end

while true do 
   parallel.waitForAny(listenKeys, requestSender, serverFulfillmentDataResponse, chatboxHandler, chatboxTimerResponder)

   if quit then
       print("Quitting....")
       sleep(0.001)
       term.clear()
       break
     end

    --  sleep(0.05)
end
