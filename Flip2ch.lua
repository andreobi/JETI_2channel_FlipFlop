--
local appName = "2 Channel FlipFlop"
-- Seriallized values - parameter
local swItem={}		-- 8 Input swItems
local swLogic={}	-- logic 1:only, 2:and, 3:or
local swMode={}		-- transition 1:level, 2:edge
local fdName={}		-- channel name long label
local delTime={}	-- delay time in 10ms
local fdCtrId={}	-- registered control channel 0: non
-- program 
local gateOld={}
local fOut={}
local delayedOut={}
local trigTime={}

----------------------------------------------------------------------
-- Error Handling
local function doError(text)
	system.messageBox(text,5)
	system.playBeep(3,400,1000)
end

----------------------------------------------------------------------
-- get FD short name for channel fd
local function getFDsname(fd)
	if fd>9 then return "F"..fd
			else return "FD"..fd
	end
end

----------------------------------------------------------------------
-- Form initialization
local function initForm(subform)
	local swCtrl={}
	local fdCtrl={}

-- Function callbacks
	local function fdNameChnged(value,n)
		if fdCtrId[n]==0 or system.registerControl(fdCtrId[n],value,getFDsname(fdCtrId[n]))==nil then
			doError("FD"..fdCtrId[n].." not registered")
		end
		fdName[n]=value
		system.pSave("fdName",fdName)
	end
--
	local function swItemChanged(value,n)
		swItem[n]=value
		system.pSave("swItem"..n,swItem[n])
	end
--
	local function swLogicChanged(value,n)
		swLogic[n]=value
		local en=true
		if swLogic[n]==1 then en=false end
		form.setProperties(swCtrl[n],{width=70,visible=en})
		system.pSave("swLogic",swLogic)
	end
--
	local function swModeChanged(value,n)
		swMode[n]=value
		system.pSave("swMode",swMode)
	end
--
	local function ctrlIdChanged(cid,n)
		local done=false
		local cntUp=false

		local function nextCid()
			if cntUp then cid=cid+1
			else cid=cid-1 end
		end

		if cid>fdCtrId[n] then cntUp=true end
		repeat
			if cid==fdCtrId[(n%2)+1] then nextCid() end	-- don't overwrite the secound channel
			if cid>10 or cid<1 then					-- out off range
				cid=fdCtrId[n]
				done=true
			else									-- try the desired Index
				local test=system.registerControl(cid,fdName[n],getFDsname(cid))
				if test~=nil then
					done=true
					if fdCtrId[n]>0 then system.unregisterControl(fdCtrId[n]) end
					cid=test
					fdCtrId[n]=test
					system.pSave("fdCtrId",fdCtrId)
				else								-- desired channel failed
					nextCid()
				end
			end
		until done
		form.setValue(fdCtrl[n],cid)				-- show the registered channel
	end
--
	local function delTimeChanged(value,n)
		delTime[n]=value
		system.pSave("delTime",delTime)
	end
-- start menu
	local lb={"Set","Clear"}
	for n=1,2,1 do
		form.addRow(5)
		form.addLabel({label="FD",font=FONT_BOLD,width=30,enabled=false})
		fdCtrl[n]=form.addIntbox(fdCtrId[n],1, 10,n,0,1,function(v) ctrlIdChanged(v,n) end,{width=45})		
		form.addTextbox(fdName[n],20,function(v) fdNameChnged(v,n) end,{width=140})
		form.addLabel({label="t(s)",width=35})
		form.addIntbox(delTime[n], 0, 10000,100,2,1,function(v) delTimeChanged(v,n) end,{width=85})
		for i=1,2,1 do
			local id4=i+2*(n-1)
			local id8=1+2*(i-1)+4*(n-1)
			form.addRow(5)
			form.addLabel({label=lb[i],width=48})
			form.addInputbox(swItem[id8],false,function(v) swItemChanged(v,id8) end,{width=70})
			form.addSelectbox({" ","and","or"},swLogic[id4],false,function(v) swLogicChanged(v,id4) end,{width=57})
			local en=true
			if swLogic[id4]==1 then en=false end
			swCtrl[id4]=form.addInputbox(swItem[id8+1],false,function(v) swItemChanged(v,id8+1) end,{width=70,visible=en})
			form.addSelectbox({"Level","Edge"},swMode[id4],false,function(v) swModeChanged(v,id4) end,{width=75})
		end
	end
end

----------------------------------------------------------------------
-- Print function - prints the output channels
local function printForm()
	local lab=getFDsname(fdCtrId[1])
	if fdCtrId[1]==0 then lab=lab.." : ---"
	else lab=lab.." : "..delayedOut[1] end
	lcd.drawText(12,132,lab,FONT_MINI)

	lab=getFDsname(fdCtrId[2])
	if fdCtrId[2]==0 then lab=lab.." : ---"
	else lab=lab.." : "..delayedOut[2] end
	lcd.drawText(80,132,lab,FONT_MINI)
end

----------------------------------------------------------------------
-- gate logic
local function doGate(g)
-- valid parameter
	if g<1 or g>4 then 
		doError("FD --- E R R O R")
		return false 
	end
-- default state
	local gate=0
	local change=false
-- read
	if swItem[2*g-1]~=nil 
	then swA=system.getInputsVal(swItem[2*g-1])
	else swA=-1 end
	if swItem[2*g]~=nil 
	then swB=system.getInputsVal(swItem[2*g])
	else swB=-1 end
-- logic
	if 		swLogic[g]==1 then	if swA>0 then gate=1 end
	elseif 	swLogic[g]==2 then	if swA>0 and swB>0 then gate=1 end
	else						if swA>0 or  swB>0 then gate=1 end
	end
-- mode
	if swMode[g]==1
	then	if gate==1 then change=true end
	else	if gate==1 and gateOld[g]==0 then change=true end
	end
	gateOld[g]=gate
--
	return change
end

----------------------------------------------------------------------
-- Runtime function
local function loop()
	local curTime = system.getTimeCounter()
	for n=1,2,1 do
--Set
		if doGate(2*n-1) then fOut[n]=1 end
--Clear
		if doGate(2*n) then fOut[n]=-1 end
--Delay
		if fOut[n]==1 then
			delayedOut[n]=1
			trigTime[n] = curTime + delTime[n] * 10
		elseif (trigTime[n] <= curTime) then
			delayedOut[n]=-1
		end
-- Set control channel
		if fdCtrId[n]>0 then					-- handle control channel
			if not pcall(function() system.setControl(fdCtrId[n],delayedOut[n],0,0) end) then
				doError("FD"..n.."  E R R O R")
			end
		end
	end
end

----------------------------------------------------------------------
-- Init
local function init()
	local curTime = system.getTimeCounter()
-- read parameter
	system.registerForm(1,MENU_APPS,appName,initForm,nil,printForm)
	for i=1,8,1 do 
		swItem[i]=system.pLoad("swItem"..i,nil)
	end
	swLogic= system.pLoad("swLogic",{1,1,1,1})
	swMode = system.pLoad("swMode", {1,1,1,1})
	fdName = system.pLoad("fdName", {"Log Control","Push to Talk"})
	delTime= system.pLoad("delTime",{1000,190})
	fdCtrId= system.pLoad("fdCtrId",{1,2})
-- init program values
	for n=1,2,1 do
		doGate(2*n-1)
		doGate(2*n)
		fOut[n]=-1
		delayedOut[n]=-1
		if fdCtrId[n]==nil or fdCtrId[n]<1 or fdCtrId[n]>10 then
			fdCtrId[n]=0
			doError("FFD"..n.." not defined")
		else
			fdCtrId[n]=system.registerControl(fdCtrId[n],fdName[n],getFDsname(fdCtrId[n]))
			if fdCtrId[n]~=nil then
				system.setControl(fdCtrId[n],delayedOut[n],0,0)
			else
				fdCtrId[n]=0
				doError("FD"..n.." not registered")
			end
		end
		trigTime[n] = curTime
	end
end
----------------------------------------------------------------------

return {init=init, loop=loop, author="Andre", version="0.58", name=appName}
