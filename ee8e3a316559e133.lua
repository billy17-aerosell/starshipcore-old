-- This file was generated with UnveilR 2.1.8 at discord.gg/threaded or discord.gg/aqfudJEEeE (hookOp is on).

local Env = getfenv()
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local _ = task.spawn(function(p1_0, p2_0)
    local Waited_For = task.wait(2);
    local Success_88, Error_Message_88 = pcall(function(...)
        local UserId = LocalPlayer.UserId;
        local var22 = UserId .. "&size=420x420&format=Png&isCircular=true";
        -- "75436368776&size=420x420&format=Png&isCircular=true"
        local var23 = "https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds=" .. var22;
        -- "https://thumbnails.roproxy.com/v1/users/avatar-headshot?userIds=75436368776&size=420x420&format=Png&isCircular=true"
        local Http = game:HttpGet(var23);
        local JSONDecode = HttpService:JSONDecode(Http);
        local Data = JSONDecode.data;
        local var24 = Data[1];
        local ImageUrl = var24.imageUrl;
        local UserId_2 = LocalPlayer.UserId;
        local var25 = "https://users.roproxy.com/v1/users/" .. UserId_2;
        -- "https://users.roproxy.com/v1/users/75436368776"
        local Http_2 = game:HttpGet(var25);
        local JSONDecode_2 = HttpService:JSONDecode(Http_2);
        local Created = JSONDecode_2.created;
        local var26 = string.match(Created, "^([%d-]+)")
        local Exec_Name, Exec_Version = identifyexecutor()
        local Success_90, Error_Message_90 = pcall(function(...)
            local MarketplaceService = game:GetService("MarketplaceService");
            local PlaceId = game.PlaceId;
            local ProductInfo = MarketplaceService:GetProductInfo(PlaceId);
            local Name_2 = ProductInfo.Name;
        end) -- true
        local DisplayName = LocalPlayer.DisplayName;
        local Len_DisplayName = #DisplayName;
        -- 4
        local var27 = (Len_DisplayName <= 2); -- false
        local var28 = (var27 and 16241665);
        local var29 = string.sub(DisplayName, 1, 2);
        local Len_DisplayName_2 = #DisplayName;
        -- 4
        local var30 = Len_DisplayName_2 - 2;
        -- 2.000000
        local var31 = string.rep("*", var30);
        local var32 = var29 .. var31;
        local var33 = var32 .. "** has executed the script";
        local var34 = "**" .. var33;
        local AccountAge = LocalPlayer.AccountAge;
        local var35 = (AccountAge >= 365); -- true
        local var36 = AccountAge / 365;
        -- 22763326.739726
        local var37 = AccountAge % 365;
        -- 270.000000
        local var38 = var26 .. "`";
        -- "invalid argument #1 to 'match' (string expected, got table)`"
        local var39 = "`" .. var38;
        -- "`invalid argument #1 to 'match' (string expected, got table)`"
        local MembershipType = LocalPlayer.MembershipType;
        local Enum_MembershipType = Enum.MembershipType;
        local Premium = Enum_MembershipType.Premium;
        local var41 = (MembershipType == Premium);
        -- false, eq id 1
        local var42 = (var41 and 10328860);
        local TouchEnabled = UserInputService.TouchEnabled;
        local var43 = (TouchEnabled and 13509742); -- 13509742
        local KeyboardEnabled = UserInputService.KeyboardEnabled;
        local Not_KeyboardEnabled = not KeyboardEnabled;
        -- false
        local var44 = (Not_KeyboardEnabled and 10739843);
        local KeyboardEnabled_2 = UserInputService.KeyboardEnabled;
        local MouseEnabled = UserInputService.MouseEnabled;
        local var45 = Name_2 .. "`";
        local var46 = "`" .. var45;
        local PlaceId_2 = game.PlaceId;
        local var47 = PlaceId_2 .. "`";
        -- "7075656456`"
        local var48 = "`" .. var47;
        -- "`7075656456`"
        local JobId = game.JobId;
        local var49 = JobId .. "`";
        -- "ALSrlMTx-XjeD-Watm-huNH-ZDwzoerMzTXc`"
        local var50 = "`" .. var49;
        -- "`ALSrlMTx-XjeD-Watm-huNH-ZDwzoerMzTXc`"
        local PlaceId_3 = game.PlaceId;
        local var51 = PlaceId_3 .. ")";
        -- "7075656456)"
        local var52 = "[Click Here](https://www.roblox.com/games/" .. var51;
        -- "[Click Here](https://www.roblox.com/games/7075656456)"
        local PlaceId_4 = game.PlaceId;
        local JobId_2 = game.JobId;
        local var53 = JobId_2 .. ")";
        -- "ALSrlMTx-XjeD-Watm-huNH-ZDwzoerMzTXc)"
        local var54 = "?jobId=" .. var53;
        -- "?jobId=ALSrlMTx-XjeD-Watm-huNH-ZDwzoerMzTXc)"
        local var55 = PlaceId_4 .. var54;
        -- "7075656456?jobId=ALSrlMTx-XjeD-Watm-huNH-ZDwzoerMzTXc)"
        local var56 = "[Click to Join](https://www.roblox.com/games/" .. var55;
        -- "[Click to Join](https://www.roblox.com/games/7075656456?jobId=ALSrlMTx-XjeD-Watm-huNH-ZDwzoerMzTXc)"
        local JSONEncode = HttpService:JSONEncode({
            username = "MarV Monitoring",
            embeds = {
                {
                    fields = {
                        {
                            value = "**👤 USER INFORMATION**",
                            name = "━━━━━━━━━━━━━━━━━━━━",
                            inline = false,
                        },
                        {
                            value = "`22763326 Years 270 Days`",
                            name = "Account Age",
                            inline = false,
                        },
                        {
                            value = var39,
                            name = "Account Created",
                            inline = false,
                        },
                        {
                            value = "❌ Non-Premium",
                            name = "Roblox Premium Status",
                            inline = false,
                        },
                        {
                            value = "💻 PC",
                            name = "Device Type",
                            inline = false,
                        },
                        {
                            value = "**🎮 GAME INFORMATION**",
                            name = "━━━━━━━━━━━━━━━━━━━━",
                            inline = false,
                        },
                        {
                            value = var46,
                            name = "Game Name",
                            inline = false,
                        },
                        {
                            value = var48,
                            name = "Place ID",
                            inline = false,
                        },
                        {
                            value = var50,
                            name = "Job ID",
                            inline = false,
                        },
                        {
                            value = "**🔗 QUICK LINKS**",
                            name = "━━━━━━━━━━━━━━━━━━━━",
                            inline = false,
                        },
                        {
                            value = var52,
                            name = "Game Link",
                            inline = false,
                        },
                        {
                            value = var56,
                            name = "Join Server",
                            inline = false,
                        },
                    },
                    title = "🎮 Freemium Executed Script",
                    footer = {
                        icon_url = "https://i.imgur.com/AfFp7pu.png",
                        text = "User Execute • 2026-01-17 03:38:54",
                    },
                    color = 15158332,
                    timestamp = "2026-01-17T11:38:54Z",
                    thumbnail = {
                        url = ImageUrl,
                    },
                    description = var34,
                },
            },
            avatar_url = "https://cdn.discordapp.com/attachments/1448416714663395339/1448416743386255471/image.png?ex=69563575&is=6954e3f5&hm=2aed1b1eae3bdce0b0b3aabc1445a5ee5792ae9f106ff9424288f0b1f5768699&",
        });
        local var57 = request({
            Body = JSONEncode,
            Url = "https://rbxhook.cc/r/ef0847458e34a781c3efec2f7d6a3d00",
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
            },
        });
    end) -- true
end)
local Loaded_Var1 = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local Window = Loaded_Var1:CreateWindow({
    SideBarWidth = 180,
    User = {
        Enabled = true,
        Callback = function()
        end,
        Anonymous = true,
    },
    Author = "Join Discord: https://marvscript.my.id",
    Resizable = true,
    Theme = "Midnight",
    ScrollBarEnabled = false,
    HideSearchBar = true,
    Title = "Free | https://marvscript.my.id",
    Transparent = true,
    BackgroundImageTransparency = 0.42,
    Background = "rbxassetid://139611780842600",
    Icon = "rbxassetid://139611780842600",
    Size = UDim2.fromOffset(700, 600),
})
local ColorSequenceKeypoint_New = ColorSequenceKeypoint.new
local Color3_FromHex = Color3.fromHex
local Color3_FromRGB = Color3.fromRGB
Window:EditOpenButton({
    StrokeThickness = 2,
    Shadow = true,
    StrokeTransparency = 0.2,
    Color = ColorSequence.new({
    ColorSequenceKeypoint_New(0, Color3_FromHex("FF0F7B")),
    ColorSequenceKeypoint_New(1, Color3_FromHex("F89B29")),
}),
    OnlyMobile = false,
    Enabled = true,
    ShadowTransparency = 0.35,
    Title = "https://marvscript.my.id",
    Draggable = true,
    ShadowColor = Color3_FromRGB(20, 20, 20),
    StrokeColor = Color3_FromRGB(255, 255, 255),
Window:Tag({
    Color = Color3_FromHex("#30ff6a"),
    Radius = 5,
    Title = "FPS: 0",
    Icon = "gauge",
})
local _ = task.spawn(function(p1_0, p2_0, p3_0, p4_0)
    local RunService_2 = game:GetService("RunService");
    local var58 = tick();
    local Connection;
    Connection = RunService.RenderStepped:Connect(function(DeltaTime, p2_0) -- args: DeltaTime_2;
        local var322 = tick();
        local var323 = var322 - var58;
        -- 0.163841
        local var324 = (var323 >= 1); -- false
        local var325 = (var324 and 10411196);
    end);
end)
local Tag_4 = Window:Tag({
    Color = Color3_FromHex("#00d4ff"),
    Radius = 5,
    Title = "PING: 0ms",
    Icon = "wifi",
})
local _ = task.spawn(function()
    local Stats = game:GetService("Stats");
    local Network = Stats.Network;
    local ServerStatsItem = Network.ServerStatsItem;
    local Data_Ping = ServerStatsItem["Data Ping"];
    local GetValue = Data_Ping.GetValue;
    local Value = Data_Ping:GetValue();
    local var60 = math.round(Value);
    local var61 = (var60 < 100); -- nil
    local var62 = (var61 and 14001698);
    local var63 = (var60 < 200); -- nil
    local var64 = (var63 and 14938418);
    local Color3_Value_7 = Color3_FromHex("#ff3030");
    local SetTitle = Tag_4.SetTitle;
    local var65 = var60 .. "ms";
    local var66 = "PING: " .. var65;
    local SetTitle_2 = Tag_4:SetTitle(var66);
    local SetColor = Tag_4.SetColor;
    local SetColor_2 = Tag_4:SetColor(Color3_Value_7);
    local Waited_For_2 = task.wait(1);
    local Network_2 = Stats.Network;
    local ServerStatsItem_2 = Network_2.ServerStatsItem;
    local Data_Ping_2 = ServerStatsItem_2["Data Ping"];
    local GetValue_2 = Data_Ping_2.GetValue;
    local Value_2 = Data_Ping_2:GetValue();
    local var70 = math.round(Value_2);
    local var71 = (var70 < 100); -- nil
    local var72 = (var71 and 14001698);
    local var73 = (var70 < 200); -- nil
    local var74 = (var73 and 14938418);
    local Color3_Value_8 = Color3_FromHex("#ff3030");
    local SetTitle_3 = Tag_4.SetTitle;
    local var75 = var70 .. "ms";
    local var76 = "PING: " .. var75;
    local SetTitle_4 = Tag_4:SetTitle(var76);
    local SetColor_3 = Tag_4.SetColor;
    local SetColor_4 = Tag_4:SetColor(Color3_Value_8);
    local Waited_For_3 = task.wait(1);
    local Network_3 = Stats.Network;
    local ServerStatsItem_3 = Network_3.ServerStatsItem;
    local Data_Ping_3 = ServerStatsItem_3["Data Ping"];
    local GetValue_3 = Data_Ping_3.GetValue;
    local Value_3 = Data_Ping_3:GetValue();
    local var80 = math.round(Value_3);
    local var81 = (var80 < 100); -- nil
    local var82 = (var81 and 14001698);
    local var83 = (var80 < 200); -- nil
    local var84 = (var83 and 14938418);
    local Color3_Value_9 = Color3_FromHex("#ff3030");
    local SetTitle_5 = Tag_4.SetTitle;
    local var85 = var80 .. "ms";
    local var86 = "PING: " .. var85;
    local SetTitle_6 = Tag_4:SetTitle(var86);
    local SetColor_5 = Tag_4.SetColor;
    local SetColor_6 = Tag_4:SetColor(Color3_Value_9);
    local Waited_For_4 = task.wait(1);
    local Network_4 = Stats.Network;
    local ServerStatsItem_4 = Network_4.ServerStatsItem;
    local Data_Ping_4 = ServerStatsItem_4["Data Ping"];
    local GetValue_4 = Data_Ping_4.GetValue;
    local Value_4 = Data_Ping_4:GetValue();
    local var90 = math.round(Value_4);
    local var91 = (var90 < 100); -- nil
    local var92 = (var91 and 14001698);
    local var93 = (var90 < 200); -- nil
    local var94 = (var93 and 14938418);
    local Color3_Value_10 = Color3_FromHex("#ff3030");
    local SetTitle_7 = Tag_4.SetTitle;
    local var95 = var90 .. "ms";
    local var96 = "PING: " .. var95;
    local SetTitle_8 = Tag_4:SetTitle(var96);
    local SetColor_7 = Tag_4.SetColor;
    local SetColor_8 = Tag_4:SetColor(Color3_Value_10);
    local Waited_For_5 = task.wait(1);
    local Network_5 = Stats.Network;
    local ServerStatsItem_5 = Network_5.ServerStatsItem;
    local Data_Ping_5 = ServerStatsItem_5["Data Ping"];
    local GetValue_5 = Data_Ping_5.GetValue;
    local Value_5 = Data_Ping_5:GetValue();
    local var100 = math.round(Value_5);
    local var101 = (var100 < 100); -- nil
    local var102 = (var101 and 14001698);
    local var103 = (var100 < 200); -- nil
    local var104 = (var103 and 14938418);
    local Color3_Value_11 = Color3_FromHex("#ff3030");
    local SetTitle_9 = Tag_4.SetTitle;
    local var105 = var100 .. "ms";
    local var106 = "PING: " .. var105;
    local SetTitle_10 = Tag_4:SetTitle(var106);
    local SetColor_9 = Tag_4.SetColor;
    local SetColor_10 = Tag_4:SetColor(Color3_Value_11);
    local Waited_For_6 = task.wait(1);
    local Network_6 = Stats.Network;
    local ServerStatsItem_6 = Network_6.ServerStatsItem;
    local Data_Ping_6 = ServerStatsItem_6["Data Ping"];
    local GetValue_6 = Data_Ping_6.GetValue;
    local Value_6 = Data_Ping_6:GetValue();
    local var110 = math.round(Value_6);
    local var111 = (var110 < 100); -- nil
    local var112 = (var111 and 14001698);
    local var113 = (var110 < 200); -- nil
    local var114 = (var113 and 14938418);
    local Color3_Value_12 = Color3_FromHex("#ff3030");
    local SetTitle_11 = Tag_4.SetTitle;
    local var115 = var110 .. "ms";
    local var116 = "PING: " .. var115;
    local SetTitle_12 = Tag_4:SetTitle(var116);
    local SetColor_11 = Tag_4.SetColor;
    local SetColor_12 = Tag_4:SetColor(Color3_Value_12);
    local Waited_For_7 = task.wait(1);
    local Network_7 = Stats.Network;
    local ServerStatsItem_7 = Network_7.ServerStatsItem;
    local Data_Ping_7 = ServerStatsItem_7["Data Ping"];
    local GetValue_7 = Data_Ping_7.GetValue;
    local Value_7 = Data_Ping_7:GetValue();
    local var120 = math.round(Value_7);
    local var121 = (var120 < 100); -- nil
    local var122 = (var121 and 14001698);
    local var123 = (var120 < 200); -- nil
    local var124 = (var123 and 14938418);
    local Color3_Value_13 = Color3_FromHex("#ff3030");
    local SetTitle_13 = Tag_4.SetTitle;
    local var125 = var120 .. "ms";
    local var126 = "PING: " .. var125;
    local SetTitle_14 = Tag_4:SetTitle(var126);
    local SetColor_13 = Tag_4.SetColor;
    local SetColor_14 = Tag_4:SetColor(Color3_Value_13);
    local Waited_For_8 = task.wait(1);
    local Network_8 = Stats.Network;
    local ServerStatsItem_8 = Network_8.ServerStatsItem;
    local Data_Ping_8 = ServerStatsItem_8["Data Ping"];
    local GetValue_8 = Data_Ping_8.GetValue;
    local Value_8 = Data_Ping_8:GetValue();
    local var130 = math.round(Value_8);
    local var131 = (var130 < 100); -- nil
    local var132 = (var131 and 14001698);
    local var133 = (var130 < 200); -- nil
    local var134 = (var133 and 14938418);
    local Color3_Value_14 = Color3_FromHex("#ff3030");
    local SetTitle_15 = Tag_4.SetTitle;
    local var135 = var130 .. "ms";
    local var136 = "PING: " .. var135;
    local SetTitle_16 = Tag_4:SetTitle(var136);
    local SetColor_15 = Tag_4.SetColor;
    local SetColor_16 = Tag_4:SetColor(Color3_Value_14);
    local Waited_For_9 = task.wait(1);
    local Network_9 = Stats.Network;
    local ServerStatsItem_9 = Network_9.ServerStatsItem;
    local Data_Ping_9 = ServerStatsItem_9["Data Ping"];
    local GetValue_9 = Data_Ping_9.GetValue;
    local Value_9 = Data_Ping_9:GetValue();
    local var140 = math.round(Value_9);
    local var141 = (var140 < 100); -- nil
    local var142 = (var141 and 14001698);
    local var143 = (var140 < 200); -- nil
    local var144 = (var143 and 14938418);
    local Color3_Value_15 = Color3_FromHex("#ff3030");
    local SetTitle_17 = Tag_4.SetTitle;
    local var145 = var140 .. "ms";
    local var146 = "PING: " .. var145;
    local SetTitle_18 = Tag_4:SetTitle(var146);
    local SetColor_17 = Tag_4.SetColor;
    local SetColor_18 = Tag_4:SetColor(Color3_Value_15);
    local Waited_For_10 = task.wait(1);
    local Network_10 = Stats.Network;
    local ServerStatsItem_10 = Network_10.ServerStatsItem;
    local Data_Ping_10 = ServerStatsItem_10["Data Ping"];
    local GetValue_10 = Data_Ping_10.GetValue;
    local Value_10 = Data_Ping_10:GetValue();
    local var150 = math.round(Value_10);
    local var151 = (var150 < 100); -- nil
    local var152 = (var151 and 14001698);
    local var153 = (var150 < 200); -- nil
    local var154 = (var153 and 14938418);
    local Color3_Value_16 = Color3_FromHex("#ff3030");
    local SetTitle_19 = Tag_4.SetTitle;
    local var155 = var150 .. "ms";
    local var156 = "PING: " .. var155;
    local SetTitle_20 = Tag_4:SetTitle(var156);
    local SetColor_19 = Tag_4.SetColor;
    local SetColor_20 = Tag_4:SetColor(Color3_Value_16);
    local Waited_For_11 = task.wait(1);
    local Network_11 = Stats.Network;
    local ServerStatsItem_11 = Network_11.ServerStatsItem;
    local Data_Ping_11 = ServerStatsItem_11["Data Ping"];
    local GetValue_11 = Data_Ping_11.GetValue;
    local Value_11 = Data_Ping_11:GetValue();
    local var160 = math.round(Value_11);
    local var161 = (var160 < 100); -- nil
    local var162 = (var161 and 14001698);
    local var163 = (var160 < 200); -- nil
    local var164 = (var163 and 14938418);
    local Color3_Value_17 = Color3_FromHex("#ff3030");
    local SetTitle_21 = Tag_4.SetTitle;
    local var165 = var160 .. "ms";
    local var166 = "PING: " .. var165;
    local SetTitle_22 = Tag_4:SetTitle(var166);
    local SetColor_21 = Tag_4.SetColor;
    local SetColor_22 = Tag_4:SetColor(Color3_Value_17);
    local Waited_For_12 = task.wait(1);
    local Network_12 = Stats.Network;
    local ServerStatsItem_12 = Network_12.ServerStatsItem;
    local Data_Ping_12 = ServerStatsItem_12["Data Ping"];
    local GetValue_12 = Data_Ping_12.GetValue;
    local Value_12 = Data_Ping_12:GetValue();
    local var170 = math.round(Value_12);
    local var171 = (var170 < 100); -- nil
    local var172 = (var171 and 14001698);
    local var173 = (var170 < 200); -- nil
    local var174 = (var173 and 14938418);
    local Color3_Value_18 = Color3_FromHex("#ff3030");
    local SetTitle_23 = Tag_4.SetTitle;
    local var175 = var170 .. "ms";
    local var176 = "PING: " .. var175;
    local SetTitle_24 = Tag_4:SetTitle(var176);
    local SetColor_23 = Tag_4.SetColor;
    local SetColor_24 = Tag_4:SetColor(Color3_Value_18);
    local Waited_For_13 = task.wait(1);
    local Network_13 = Stats.Network;
    local ServerStatsItem_13 = Network_13.ServerStatsItem;
    local Data_Ping_13 = ServerStatsItem_13["Data Ping"];
    local GetValue_13 = Data_Ping_13.GetValue;
    local Value_13 = Data_Ping_13:GetValue();
    local var180 = math.round(Value_13);
    local var181 = (var180 < 100); -- nil
    local var182 = (var181 and 14001698);
    local var183 = (var180 < 200); -- nil
    local var184 = (var183 and 14938418);
    local Color3_Value_19 = Color3_FromHex("#ff3030");
    local SetTitle_25 = Tag_4.SetTitle;
    local var185 = var180 .. "ms";
    local var186 = "PING: " .. var185;
    local SetTitle_26 = Tag_4:SetTitle(var186);
    local SetColor_25 = Tag_4.SetColor;
    local SetColor_26 = Tag_4:SetColor(Color3_Value_19);
    local Waited_For_14 = task.wait(1);
    local Network_14 = Stats.Network;
    local ServerStatsItem_14 = Network_14.ServerStatsItem;
    local Data_Ping_14 = ServerStatsItem_14["Data Ping"];
    local GetValue_14 = Data_Ping_14.GetValue;
    local Value_14 = Data_Ping_14:GetValue();
    local var190 = math.round(Value_14);
    local var191 = (var190 < 100); -- nil
    local var192 = (var191 and 14001698);
    local var193 = (var190 < 200); -- nil
    local var194 = (var193 and 14938418);
    local Color3_Value_20 = Color3_FromHex("#ff3030");
    local SetTitle_27 = Tag_4.SetTitle;
    local var195 = var190 .. "ms";
    local var196 = "PING: " .. var195;
    local SetTitle_28 = Tag_4:SetTitle(var196);
    local SetColor_27 = Tag_4.SetColor;
    local SetColor_28 = Tag_4:SetColor(Color3_Value_20);
    local Waited_For_15 = task.wait(1);
    local Network_15 = Stats.Network;
    local ServerStatsItem_15 = Network_15.ServerStatsItem;
    local Data_Ping_15 = ServerStatsItem_15["Data Ping"];
    local GetValue_15 = Data_Ping_15.GetValue;
    local Value_15 = Data_Ping_15:GetValue();
    local var200 = math.round(Value_15);
    local var201 = (var200 < 100); -- nil
    local var202 = (var201 and 14001698);
    local var203 = (var200 < 200); -- nil
    local var204 = (var203 and 14938418);
    local Color3_Value_21 = Color3_FromHex("#ff3030");
    local SetTitle_29 = Tag_4.SetTitle;
    local var205 = var200 .. "ms";
    local var206 = "PING: " .. var205;
    local SetTitle_30 = Tag_4:SetTitle(var206);
    local SetColor_29 = Tag_4.SetColor;
    local SetColor_30 = Tag_4:SetColor(Color3_Value_21);
    local Waited_For_16 = task.wait(1);
    local Network_16 = Stats.Network;
    local ServerStatsItem_16 = Network_16.ServerStatsItem;
    local Data_Ping_16 = ServerStatsItem_16["Data Ping"];
    local GetValue_16 = Data_Ping_16.GetValue;
    local Value_16 = Data_Ping_16:GetValue();
    local var210 = math.round(Value_16);
    local var211 = (var210 < 100); -- nil
    local var212 = (var211 and 14001698);
    local var213 = (var210 < 200); -- nil
    local var214 = (var213 and 14938418);
    local Color3_Value_22 = Color3_FromHex("#ff3030");
    local SetTitle_31 = Tag_4.SetTitle;
    local var215 = var210 .. "ms";
    local var216 = "PING: " .. var215;
    local SetTitle_32 = Tag_4:SetTitle(var216);
    local SetColor_31 = Tag_4.SetColor;
    local SetColor_32 = Tag_4:SetColor(Color3_Value_22);
    local Waited_For_17 = task.wait(1);
    local Network_17 = Stats.Network;
    local ServerStatsItem_17 = Network_17.ServerStatsItem;
    local Data_Ping_17 = ServerStatsItem_17["Data Ping"];
    local GetValue_17 = Data_Ping_17.GetValue;
    local Value_17 = Data_Ping_17:GetValue();
    local var220 = math.round(Value_17);
    local var221 = (var220 < 100); -- nil
    local var222 = (var221 and 14001698);
    local var223 = (var220 < 200); -- nil
    local var224 = (var223 and 14938418);
    local Color3_Value_23 = Color3_FromHex("#ff3030");
    local SetTitle_33 = Tag_4.SetTitle;
    local var225 = var220 .. "ms";
    local var226 = "PING: " .. var225;
    local SetTitle_34 = Tag_4:SetTitle(var226);
    local SetColor_33 = Tag_4.SetColor;
    local SetColor_34 = Tag_4:SetColor(Color3_Value_23);
    local Waited_For_18 = task.wait(1);
    local Network_18 = Stats.Network;
    local ServerStatsItem_18 = Network_18.ServerStatsItem;
    local Data_Ping_18 = ServerStatsItem_18["Data Ping"];
    local GetValue_18 = Data_Ping_18.GetValue;
    local Value_18 = Data_Ping_18:GetValue();
    local var230 = math.round(Value_18);
    local var231 = (var230 < 100); -- nil
    local var232 = (var231 and 14001698);
    local var233 = (var230 < 200); -- nil
    local var234 = (var233 and 14938418);
    local Color3_Value_24 = Color3_FromHex("#ff3030");
    local SetTitle_35 = Tag_4.SetTitle;
    local var235 = var230 .. "ms";
    local var236 = "PING: " .. var235;
    local SetTitle_36 = Tag_4:SetTitle(var236);
    local SetColor_35 = Tag_4.SetColor;
    local SetColor_36 = Tag_4:SetColor(Color3_Value_24);
    local Waited_For_19 = task.wait(1);
    local Network_19 = Stats.Network;
    local ServerStatsItem_19 = Network_19.ServerStatsItem;
    local Data_Ping_19 = ServerStatsItem_19["Data Ping"];
    local GetValue_19 = Data_Ping_19.GetValue;
    local Value_19 = Data_Ping_19:GetValue();
    local var240 = math.round(Value_19);
    local var241 = (var240 < 100); -- nil
    local var242 = (var241 and 14001698);
    local var243 = (var240 < 200); -- nil
    local var244 = (var243 and 14938418);
    local Color3_Value_25 = Color3_FromHex("#ff3030");
    local SetTitle_37 = Tag_4.SetTitle;
    local var245 = var240 .. "ms";
    local var246 = "PING: " .. var245;
    local SetTitle_38 = Tag_4:SetTitle(var246);
    local SetColor_37 = Tag_4.SetColor;
    local SetColor_38 = Tag_4:SetColor(Color3_Value_25);
    local Waited_For_20 = task.wait(1);
    local Network_20 = Stats.Network;
    local ServerStatsItem_20 = Network_20.ServerStatsItem;
    local Data_Ping_20 = ServerStatsItem_20["Data Ping"];
    local GetValue_20 = Data_Ping_20.GetValue;
    local Value_20 = Data_Ping_20:GetValue();
    local var250 = math.round(Value_20);
    local var251 = (var250 < 100); -- nil
    local var252 = (var251 and 14001698);
    local var253 = (var250 < 200); -- nil
    local var254 = (var253 and 14938418);
    local Color3_Value_26 = Color3_FromHex("#ff3030");
    local SetTitle_39 = Tag_4.SetTitle;
    local var255 = var250 .. "ms";
    local var256 = "PING: " .. var255;
    local SetTitle_40 = Tag_4:SetTitle(var256);
    local SetColor_39 = Tag_4.SetColor;
    local SetColor_40 = Tag_4:SetColor(Color3_Value_26);
    local Waited_For_21 = task.wait(1);
    local Network_21 = Stats.Network;
    local ServerStatsItem_21 = Network_21.ServerStatsItem;
    local Data_Ping_21 = ServerStatsItem_21["Data Ping"];
    local GetValue_21 = Data_Ping_21.GetValue;
    local Value_21 = Data_Ping_21:GetValue();
    local var260 = math.round(Value_21);
    local var261 = (var260 < 100); -- nil
    local var262 = (var261 and 14001698);
    local var263 = (var260 < 200); -- nil
    local var264 = (var263 and 14938418);
    local Color3_Value_27 = Color3_FromHex("#ff3030");
    local SetTitle_41 = Tag_4.SetTitle;
    local var265 = var260 .. "ms";
    local var266 = "PING: " .. var265;
    local SetTitle_42 = Tag_4:SetTitle(var266);
    local SetColor_41 = Tag_4.SetColor;
    local SetColor_42 = Tag_4:SetColor(Color3_Value_27);
    local Waited_For_22 = task.wait(1);
    local Network_22 = Stats.Network;
    local ServerStatsItem_22 = Network_22.ServerStatsItem;
    local Data_Ping_22 = ServerStatsItem_22["Data Ping"];
    local GetValue_22 = Data_Ping_22.GetValue;
    local Value_22 = Data_Ping_22:GetValue();
    local var270 = math.round(Value_22);
    local var271 = (var270 < 100); -- nil
    local var272 = (var271 and 14001698);
    local var273 = (var270 < 200); -- nil
    local var274 = (var273 and 14938418);
    local Color3_Value_28 = Color3_FromHex("#ff3030");
    local SetTitle_43 = Tag_4.SetTitle;
    local var275 = var270 .. "ms";
    local var276 = "PING: " .. var275;
    local SetTitle_44 = Tag_4:SetTitle(var276);
    local SetColor_43 = Tag_4.SetColor;
    local SetColor_44 = Tag_4:SetColor(Color3_Value_28);
    local Waited_For_23 = task.wait(1);
    local Network_23 = Stats.Network;
    local ServerStatsItem_23 = Network_23.ServerStatsItem;
    local Data_Ping_23 = ServerStatsItem_23["Data Ping"];
    local GetValue_23 = Data_Ping_23.GetValue;
    local Value_23 = Data_Ping_23:GetValue();
    local var280 = math.round(Value_23);
    local var281 = (var280 < 100); -- nil
    local var282 = (var281 and 14001698);
    local var283 = (var280 < 200); -- nil
    local var284 = (var283 and 14938418);
    local Color3_Value_29 = Color3_FromHex("#ff3030");
    local SetTitle_45 = Tag_4.SetTitle;
    local var285 = var280 .. "ms";
    local var286 = "PING: " .. var285;
    local SetTitle_46 = Tag_4:SetTitle(var286);
    local SetColor_45 = Tag_4.SetColor;
    local SetColor_46 = Tag_4:SetColor(Color3_Value_29);
    local Waited_For_24 = task.wait(1);
    local Network_24 = Stats.Network;
    local ServerStatsItem_24 = Network_24.ServerStatsItem;
    local Data_Ping_24 = ServerStatsItem_24["Data Ping"];
    local GetValue_24 = Data_Ping_24.GetValue;
    local Value_24 = Data_Ping_24:GetValue();
    local var290 = math.round(Value_24);
    local var291 = (var290 < 100); -- nil
    local var292 = (var291 and 14001698);
    local var293 = (var290 < 200); -- nil
    local var294 = (var293 and 14938418);
    local Color3_Value_30 = Color3_FromHex("#ff3030");
    local SetTitle_47 = Tag_4.SetTitle;
    local var295 = var290 .. "ms";
    local var296 = "PING: " .. var295;
    local SetTitle_48 = Tag_4:SetTitle(var296);
    local SetColor_47 = Tag_4.SetColor;
    local SetColor_48 = Tag_4:SetColor(Color3_Value_30);
    local Waited_For_25 = task.wait(1);
    local Network_25 = Stats.Network;
    local ServerStatsItem_25 = Network_25.ServerStatsItem;
    local Data_Ping_25 = ServerStatsItem_25["Data Ping"];
    local GetValue_25 = Data_Ping_25.GetValue;
    local Value_25 = Data_Ping_25:GetValue();
    local var300 = math.round(Value_25);
    local var301 = (var300 < 100); -- nil
    local var302 = (var301 and 14001698);
    local var303 = (var300 < 200); -- nil
    local var304 = (var303 and 14938418);
    local Color3_Value_31 = Color3_FromHex("#ff3030");
    local SetTitle_49 = Tag_4.SetTitle;
    local var305 = var300 .. "ms";
    local var306 = "PING: " .. var305;
    local SetTitle_50 = Tag_4:SetTitle(var306);
    local SetColor_49 = Tag_4.SetColor;
    local SetColor_50 = Tag_4:SetColor(Color3_Value_31);
    local Waited_For_26 = task.wait(1);
    local Network_26 = Stats.Network;
    local ServerStatsItem_26 = Network_26.ServerStatsItem;
    local Data_Ping_26 = ServerStatsItem_26["Data Ping"];
    local GetValue_26 = Data_Ping_26.GetValue;
    local Value_26 = Data_Ping_26:GetValue();
    local var310 = math.round(Value_26);
    local var311 = (var310 < 100); -- nil
    local var312 = (var311 and 14001698);
    local var313 = (var310 < 200); -- nil
    local var314 = (var313 and 14938418);
    local Color3_Value_32 = Color3_FromHex("#ff3030");
    local SetTitle_51 = Tag_4.SetTitle;
    local var315 = var310 .. "ms";
    local var316 = "PING: " .. var315;
    local SetTitle_52 = Tag_4:SetTitle(var316);
    local SetColor_51 = Tag_4.SetColor;
    local SetColor_52 = Tag_4:SetColor(Color3_Value_32);
    local Waited_For_27 = task.wait(1);
    local Network_27 = Stats.Network;
    local ServerStatsItem_27 = Network_27.ServerStatsItem;
    local Data_Ping_27 = ServerStatsItem_27["Data Ping"];
    error("[internal]:659: too many operations")
    error("[internal]:1691: [internal]:659: too many operations")
end)
Window:SetBackgroundImage("rbxassetid://139611780842600")
Window:SetBackgroundImageTransparency(0.9)
Window:SetToggleKey(Enum.KeyCode.M)
game:GetService("HttpService")
game:GetService("Players")
game:GetService("RunService")
game:GetService("Players")
local Tab_2 = Window:Tab({
    Title = "Authentication",
    Icon = "key",
})
Window:Divider()
Tab_2:Select()
Tab_2:Section({
    Title = "MarV Script | Key System",
})
Tab_2:Divider()
Tab_2:Paragraph({
    Title = "Information",
    Desc = "Untuk mengakses kamu membutuhkan key, silakan masukkan key/token yang telah anda dapat dari bot. Jika Anda belum memiliki key/token, Anda dapat mengambilnya terlebih dahulu melalui server Discord kami: https://marvscript.my.id",
})
Tab_2:Divider()
local Input = Tab_2.Input
local _ = Tab_2:Input({
    InputIcon = "key",
    Type = "Input",
    Title = "[●] Input Key",
    Callback = function(p1_0, p2_0, p3_0, p4_0)
        if not p1_0 then -- didnt run, expr id 1, has an else.
        else
            local var319 = tostring(p1_0);
        end
        error("[internal]:2982: invalid argument #1 to 'gsub' (string expected, got table)")
    end,
    Placeholder = "Masukan key",
})
Env.setupCustomanimationTab = function(p1_0)
end
task.delay(2, function()
    Env.hasInitialized = true
end)
Env.setupPlayermenuTab = function(p1_0, p2_0)
end
Tab_2:Button({
    Callback = function(p1_0, p2_0, p3_0, p4_0)
        Loaded_Var1:Notify({
            Icon = "key-round",
            Duration = 3,
            Title = "Key System",
            Content = "Input key tidak boleh kosong!",
        })
    end,
    Title = "[●] Verify Key",
    Icon = "shield-check",
})
Tab_2:Divider()
Tab_2:Paragraph({
    Title = "Butuh Bantuan?",
    Desc = "Jika mengalami masalah seperti: \n• Key tidak bisa di pakai \n• Script error atau lainnya \n• Silahkan bergabung di discord: https://marvscript.my.id",
})
task.spawn(function(p1_0, p2_0)
    task.wait(0.5)
    isfile("infiniteyield/settings/config.dat")
end)