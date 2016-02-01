--List of files to load
local sleep=require "socket".sleep
dofile("tableSave.lua")
math.randomseed(os.time())
commands = {}
allCommands = {}
local stepcount=0
local cmdcount = 0
local function infhook()
	stepcount = stepcount+1
	if stepcount>100000 then
		stepcount=0
		debug.sethook()
		error("Break INF LOOP")
	else
		return
	end
end
function add_cmd(f, name, lvl, help, shown, aliases)
	if type(f)~="function" then return end
	allCommands[name]={["name"]=name,["f"]=f,["level"]=lvl,["helptext"]=help,["show"]=shown}
	commands[name]=allCommands[name]
	if aliases then
		for k,v in pairs(aliases) do
			allCommands[v] = {["name"]=name,["f"]=f,["level"]=lvl,["helptext"]=help,false}
			commands[v]=allCommands[v]
		end
	end
end

--Helper to return user object from a name
function getUserFromNick(nick)
	if not nick then return end
	nick = nick:lower()
	for k,v in pairs(irc.channels) do
		if v and v.users then
			for k2,v2 in pairs(v.users) do
				if v2 and v2.nick:lower() == nick then
					return v2
				end
			end
		end
	end
end

--Load all plugins in plugins/ here
local listcmd = WINDOWS and "dir /b" or "ls"
local pluginList = io.popen(listcmd.." \"plugins\"")
for file in pluginList:lines() do
	if file:sub(#file-3,#file) == ".lua" then
		local s,e = pcall(dofile, "plugins/"..file)
		if not s then
			if config.logchannel then
				ircSendChatQ(config.logchannel, e)
			end
			print("Error loading plugins/"..file..": "..e)
		else
			print("Loaded plugins/"..file)
		end
	end
end

--CORE FUNCTIONS HERE

local function userstatus(usr,chan,msg,args)
	if chan:sub(1,1)~="#" then return "Be in chan idiot" end
	if irc.channels[chan].users[msg] then
		local info = msg.." on "..chan
		if irc.channels[chan].users[msg].access then
			info = info.." has "..irc.channels[chan].users[msg].access
		end
		ircSendChatQ(chan,info)
	end
end
add_cmd(userstatus,"userinfo",101,"Test info about someone",false)

--DISABLE a command for the bot
local function disable(usr,chan,msg,args)
	if not msg then return "Usage: '*disable <cmd> [<cmd2> ...]'" end
	if args[1]=="all" then
		for k,v in pairs(commands) do
			if k~="enable" then commands[k]=nil end
		end
		return "Disabled all"
	else
		local t={}
		for i=1,#args do
			local dcmd = args[i]:lower()
			if dcmd~="enable" and commands[dcmd] then
				commands[dcmd]=nil
				table.insert(t,dcmd)
			end
		end
		return "Disabled: "..table.concat(t," ")
	end
end
add_cmd(disable,"disable",100,"Disable a command for the bot, '*disable <cmd> [<cmd2> ...]'",true)

--ENABLE a command previously disabled
local function enable(usr,chan,msg,args)
	if not msg then return "Usage: '*enable <cmd> [<cmd2> ...]'" end
	if args[1]=="all" then
		for k,v in pairs(allCommands) do
			if not commands[k] then commands[k]=v end
		end
		return "Enabled all"
	else
		local t={}
		for i=1,#args do
			local ecmd = args[i]:lower()
			if not commands[ecmd] and allCommands[ecmd] then
				commands[ecmd]=allCommands[ecmd]
				table.insert(t,ecmd)
			end
		end
		return "Enabled: "..table.concat(t," ")
	end
end
add_cmd(enable,"enable",100,"Enables a command previously disabled, '*enable <cmd> [<cmd2> ...]'",true)

--QUIT
local function suicide(usr,chan,msg,args)
	if args[1] then
		ircSendRawQ("QUIT :"..args[1])
	else
		ircSendRawQ("QUIT :woof")
	end
	sleep(3)
	shutdown = true;
end
add_cmd(suicide,"suicide",101,"Makes the bot quit",true,{"quit","die"})

--PING
local function ping(usr,chan,msg)
	return "pong"
end
add_cmd(ping,"ping",0,"pong",true)

--DO
local function dothis(usr,chan,msg) --fix DO and ME with filters
	if msg then return "\001ACTION does "..msg.."\001",true end
end
add_cmd(dothis,"do",0,"Performs an action, '*do <text>'",true)
--ME
local function methis(usr,chan,msg)
	if msg then return "\001ACTION "..msg.."\001",true end
end
add_cmd(methis,"me",0,"Performs an action, '*me <text>'",true)

local function date(usr,chan,msg)
	return os.date()
end
add_cmd(date,"date",0,"Returns the current date, '*date'",true)

--SNEAAK
local function sneaky(usr,chan,msg)
	return "You found me!"
end
add_cmd(sneaky,"*$",0,nil,false)
local function sneaky2(usr,chan,msg)
	ircSendChatQ(usr.nick,"1 point gained")
	return nil
end
add_cmd(sneaky2,"*$woof",0,nil,false)
local function sneaky3(usr,chan,msg)
	return "WooOoOoooOoof"
end
add_cmd(sneaky3,"woof",0,nil,false)
local function sneaky4(usr,chan,msg)
	return "MooOoOoooOooo"
end
add_cmd(sneaky4,"moo",0,nil,false)


--RELOAD files
local function reload(usr,chan,msg,args)
	if not args[1] then args[1]="hooks" args[2]="commands"
	else
		if getPerms(usr.host)<101 then return "You can't use args" end
	end
	local rmsg=""
	for k,v in pairs(args) do
		local s,r = pcall(dofile,v..".lua")
		if s then
			rmsg = rmsg .. "Loaded: "..v.." "
		elseif r:find("No such file or directory") then
			s,r = pcall(dofile,"plugins/"..v..".lua")
			if s then
				rmsg = rmsg .. "Loaded: "..v.." "
			else
				rmsg = rmsg .. r .. " "
			end
		else
			rmsg = rmsg .. r .. " "
		end
	end
	return rmsg
end
add_cmd(reload,"load",100,"Loads file(s), '*load [<file1>] [<files...>]', Only admin can specify file names.",true,{"reload"})

--UPDATE the bot's source
local function update(usr,chan,msg,args)
	os.execute("git checkout . && git pull")
	--Pass the reload command
	reload(usr,chan,msg,args)
	ircSendRawQ("PRIVMSG "..config.channels.logs.." :"..usr.nick.." used *$update, I am now updated")
	ircSendRawQ("PRIVMSG "..chan.." :"..usr.nick..", Thanks for updating me, I'm now ready to rumble!")
end
add_cmd(update,"update",100,"Updates the bot to the latest Git revision and then reloads, '*update'",true,{"u","pull"})

--ECHO
local function echo(usr,chan,msg)
	return msg,true
end
add_cmd(echo,"echo",0,"Replies same text, '*$echo <text>'",true,{"say"})

--LIST
local function list(usr,chan,msg,args)
	local perm = tonumber(args[1]) or getPerms(usr.host)
	local t = {}
	local cmdcount=0
	for k,v in pairs(commands) do
		if perm>=commands[k].level and commands[k].show then
			cmdcount=cmdcount+1
			t[cmdcount]=k
		end
	end
	table.sort(t,function(x,y)return x<y end)
	return "Commands("..perm.."): " .. table.concat(t,", ")
end
add_cmd(list,"list",0,"Lists commands for the specified level, or your own, '*$list [<level>]'",true,{"ls","commands"})

--CHMOD, set a user's permission level, is temporary, add to config for permanent.
local function chmod(usr,chan,msg,args)
	if not msg then return end
	local perm = getPerms(usr.host)
	local setmax = perm-1
	local user = getUserFromNick(args[1])
	if not user then
		return "Invalid User"
	end
	local host,level = user.host:gsub("([%.%-%+%*%%%?%(%)%[%]%^%$])","%%%1"),args[2]
	if tonumber(level)~=tonumber(level) then
		return "Bad num"
	end
	if tonumber(level) > setmax then
		return "You can't set that high"
	end
	if permissions[host] and permissions[host] >= perm then
		return "You can't change this user"
	end
	permissions[host] = tonumber(level)
	return "perm['"..host.."'] = "..level
end
add_cmd(chmod,"chmod",40,"Changes a hostmask level, '*chmod <name/host> <level>'",true,{"permissions"})

--hostmask
local function getHost(usr,chan,msg,args)
	if not args[1] then return usr.host end
	local user = getUserFromNick(args[1])
	if not user then
		return "Invalid User"
	end
	return user.host
end
add_cmd(getHost,"host",0,"The host for a user, '*host <name>' Use *hostmask for full hostmask",false)

local function getHostmask(usr,chan,msg,args)
	if not args[1] then return usr.fullhost end
	local user = getUserFromNick(args[1])
	if not user then
		return "Invalid User"
	end
	return user.fullhost
end
add_cmd(getHostmask,"hostmask",0,"The hostmask for a user, '*hostmask <name>' Use *host for short host",false)

--username, for nesting
local function getName(usr,chan,msg,args)
	return usr.nick
end
add_cmd(getName,"nick",0,"Your nick, '*nick'",false)

--channel name, for nesting
local function getChan(usr,chan,msg,args)
	return chan
end
add_cmd(getChan,"chan",0,"The current channel, '*chan'",false)

--LUA full access
local function lua2(usr,chan,msg,args)
	local e,err = loadstring(msg)
	if e then
		debug.sethook(infhook,"l")
		local s,r = pcall(e)
		debug.sethook()
		stepcount=0
		if s then
			local str = tostring(r) 
			return str:gsub("[\r\n]"," ")
		else
			return "ERROR: " .. r
		end
		return
	end
	return "ERROR: " .. err
end
add_cmd(lua2,"..",101,"Runs full lua code, '*lua <code>'",false)

--HELP
local function help(usr,chan,msg)
	msg = msg or "help"
	msg = msg:lower()
	if commands[msg] then
		if commands[msg].helptext then
			return msg ..": ".. commands[msg].helptext
		end
	end
	return "No help for "..msg.." found!"
end
add_cmd(help,"help",0,"Returns hopefully helpful information, '*help <cmd>'",true)

--UNHELP, no idea
local function unhelp(usr,chan,msg)
	msg = msg or "unhelp"
	msg = msg:lower()
	if commands[msg] then
		if commands[msg].helptext then
			return msg ..": ".. string.reverse(commands[msg].helptext)
		end
	end
	if msg==string.reverse(usr.nick) then
		ircSendChatQ(usr.nick,"1 point gained")
	end
	return "No help for "..msg.." found!"
end
add_cmd(unhelp,"unhelp",0,"'>dmc< plehnu*' ,noitamrofni lufplehnu yllufepoh snruteR",true)

--TIMER
local function timer(usr,chan,msg,args)
	if #timers > 10 then
		return "Error: too many timers already"
	end
	local num = tonumber(args[1])
	if num and num==num and num<108000 and args[2] then
		local t={}
		for i=2,#args do
			table.insert(t,args[i])
		end
		local pstring = table.concat(t," ")
		addTimer(ircSendChatQ[chan][pstring],tonumber(args[1]),chan,usr.nick)
	else
		return "Bad timer"
	end
end
add_cmd(timer,"timer",0,"Time until a print is done, '*timer <time(seconds)> <text>'",true)

--BUG, report something to me in a file
local function rbug(usr,chan,msg,args)
	if not msg then error("No msg") end
	local f = io.open("bug.txt","a")
	f:write("["..os.date().."] ".. usr.host..": "..msg.."\r\n")
	f:close()
	return "Reported bug"
end
add_cmd(rbug,"bug",0,"Report something to "..config.owner.nick..", '*$bug <msg>'",true)

--SEEN, display last message by a user
local function seen(usr,chan,msg,args)
	if not args[1] then return commands["seen"].helptext end
	local nick = args[1]
	if args[1]:sub(1,1) == "#" then
		if not args[2] then return commands["seen"].helptext end
		chan, nick = args[1], args[2]
	end
	if not irc.channels[chan] then
		return "not a channel: "..chan
	elseif not irc.channels[chan].users[nick] or not irc.channels[chan].users[nick].lastSaid then
		return "I have not seen "..nick
	end
	
	local sssss = function(moo) return moo == 1 and "" or "s" end
	local difference = os.difftime(os.time(), irc.channels[chan].users[nick].lastSaid.time) or 0
	local time = os.date("!*t", difference)
	local msg = time.sec.." second"..sssss(time.sec).." ago"
	if time.min ~= 0 or difference > 86400 then msg = time.min.." minute"..sssss(time.min).." and "..msg end
	if time.hour ~= 0 or difference > 86400 then msg = time.hour.." hour"..sssss(time.hour)..", "..msg end
	time.day = time.day - 1
	if time.day ~= 0 then msg = (time.day%7).." day"..sssss(time.day%7)..", "..msg end
	if time.day >= 7 then msg = math.floor(time.day/7).." week"..sssss(time.day/7)..", "..msg end
	if time.year-1970 ~= 0 then msg = (time.year-1970).." year"..sssss(time.year-1970)..", "..msg end
	msg = nick.." was last seen in "..chan.." "..msg..": <"..nick.."> "..irc.channels[chan].users[nick].lastSaid.msg
	return msg
end
add_cmd(seen,"seen",0,"Display a last seen message '*$seen [<chan>] <nick>'",true)

--source
local function source(usr,chan,msg,args)
	if args[1] then 
		return "https://github.com/wolfy1339/WolfyBot/blob/master/"..args[1]
	else 
		return "https://github.com/wolfy1339/WolfyBot"
	end 
end
add_cmd(source,"source",0,"Display the location of my source '*source [<file>]'",true,{"github"})
