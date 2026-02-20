local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Player = game.Players.LocalPlayer
local ObstacleOverlapParams = OverlapParams.new()
local WheelOverlapParams = OverlapParams.new()
local WheelDetectionPart = Instance.new("Part")

local SteerFactor = 0.6
local SteerSpeed = 3
local MaxFlipSpeed = 8
local CollisionPredictionFrames = 2
local ObstacleHitCooldown = 0.4
local ObstacleResetDelay = 30
local ObstacleStrengthMultiplier = 200
local DamageFactor = 0.004
local SpeedBonusMultiplier = 0.1

local NormalFOV = 70
local MaxFOV = 95

local TouchedObstacles = {}
local CanControl = false
local TurnRadiusFactor = 0
local SeatPart = nil
local Wheels = nil
local CenterPart = nil
local SteerPart = nil
local CenterWeld = nil
local SteerWeld = nil
local LateralForce = nil
local TargetSteerAmount = 0
local CurrentSteerAmount = 0
local EnginePower = 0
local CurrentFuel = 0
local CurrentHealth = 0
local HitboxPart = nil
local GyroX = nil
local GyroY = nil
local GyroZ = nil
local SteerForce = nil
local FlipForce = nil
local VehicleModel = nil
local MaxWheelbaseLength = 0
local MaxWheelbaseWidth = 0
local TotalFuel = 0
local TotalStrength= 0
local VehicleDestroyed = false
local Camera = workspace.CurrentCamera


function GetSteerAngle(WheelOffset, TurnRadius)
	return TurnRadius > 0 and math.atan2(-WheelOffset.Z, TurnRadius - WheelOffset.X) or TurnRadius < 0 and math.atan2(WheelOffset.Z, WheelOffset.X - TurnRadius) or 0
end

RunService.RenderStepped:Connect(function(Dt)
	for Obstacle, ObstacleInfo in TouchedObstacles do
		if not Obstacle or not Obstacle:IsDescendantOf(workspace) or os.clock() > ObstacleInfo.ResetTime then
			TouchedObstacles[Obstacle] = nil
		end
	end
	
	if not VehicleDestroyed and SeatPart and CenterPart and HitboxPart and not SeatPart:IsGrounded() then
		local CurrentDriveVelocity = CenterPart.AssemblyLinearVelocity:Dot(CenterPart.CFrame.LookVector)
		local OverlappingHitbox = nil
		local CheckedObstacles = {}
		
		ObstacleOverlapParams.FilterDescendantsInstances = CollectionService:GetTagged("ObstacleFolder")
		HitboxPart:PivotTo(CFrame.new(CenterPart.AssemblyLinearVelocity * Dt * CollisionPredictionFrames) * CenterPart.CFrame:ToWorldSpace(CFrame.fromEulerAnglesXYZ(CenterPart.AssemblyAngularVelocity.X * Dt * CollisionPredictionFrames, CenterPart.AssemblyAngularVelocity.Y * Dt * CollisionPredictionFrames, CenterPart.AssemblyAngularVelocity.Z * Dt * CollisionPredictionFrames)))
		OverlappingHitbox = workspace:GetPartsInPart(HitboxPart, ObstacleOverlapParams)
		
		for _, Part in OverlappingHitbox do
			if Part:IsDescendantOf(workspace.GeneratedMap) then
				local Obstacle = Part

				while Obstacle.Parent.Parent.Parent ~= workspace.GeneratedMap do
					Obstacle = Obstacle.Parent
				end

				if not table.find(CheckedObstacles, Obstacle) and (not TouchedObstacles[Obstacle] or os.clock() > TouchedObstacles[Obstacle].CooldownEnd) and CenterPart.AssemblyLinearVelocity.Magnitude > 10 then
					local ObstacleCooldownEnd = os.clock() + ObstacleHitCooldown
					local ObstacleResetTime = os.clock() + ObstacleResetDelay
					local ObstacleStrength = Obstacle:GetAttribute("Strength") and Obstacle:GetAttribute("Strength") * ObstacleStrengthMultiplier or 1
					local SpeedBonus = math.pow(math.abs(CurrentDriveVelocity) * SpeedBonusMultiplier, 0.6)
					local RawVehicleDamage = TotalStrength * CenterPart.AssemblyLinearVelocity.Magnitude * DamageFactor / ObstacleStrength * (1 + SpeedBonus)
					local VehicleDamage = 0
					local ObstacleDamage = 0

					table.insert(CheckedObstacles, Obstacle)
					
					if TouchedObstacles[Obstacle] then
						TouchedObstacles[Obstacle].CooldownEnd = ObstacleCooldownEnd
						TouchedObstacles[Obstacle].ResetTime = ObstacleResetTime
					else
						TouchedObstacles[Obstacle] = {Health = 1, CooldownEnd = os.clock() + ObstacleHitCooldown, ResetTime = os.clock() + ObstacleResetDelay}
					end
					
					VehicleDamage = math.min(TotalStrength * CenterPart.AssemblyLinearVelocity.Magnitude * DamageFactor / ObstacleStrength, TouchedObstacles[Obstacle].Health)
					ObstacleDamage = ObstacleStrength * CenterPart.AssemblyLinearVelocity.Magnitude * DamageFactor / TotalStrength / (1 + SpeedBonus) * VehicleDamage / RawVehicleDamage
					
					if RawVehicleDamage >= TouchedObstacles[Obstacle].Health then
						for _, Debris in Obstacle:GetChildren() do
							if Debris:IsA("BasePart") and Debris.Name ~= "Collider" and Debris.Name ~= "Hitbox" and Debris.Name ~= "Primary" then
								local DebrisClone = Debris:Clone()

								game.Debris:AddItem(DebrisClone, 4)
								DebrisClone.Anchored = false
								DebrisClone.CollisionGroup = "Debris"
								DebrisClone.Parent = workspace.MiscStorage
								DebrisClone.CanCollide = true
								DebrisClone.CustomPhysicalProperties = PhysicalProperties.new(0.001, 2, 0.6, 100, 100)
								DebrisClone.AssemblyLinearVelocity = CenterPart.AssemblyLinearVelocity * (0.4 + math.random() * 0.4)
								DebrisClone:ApplyImpulseAtPosition(DebrisClone.Mass * (CenterPart.CFrame.Rotation * CFrame.new(((CenterPart.CFrame:Inverse() * DebrisClone.CFrame).Position.Unit + Vector3.new(math.random() * 1 - 0.5, math.random() * 0.4 + 0.4, math.random() * 1 - 0.5)) * Vector3.new(math.abs(CurrentDriveVelocity), math.abs(CurrentDriveVelocity) * 0.4, 0))).Position, (DebrisClone:GetClosestPointOnSurface(CenterPart.Position) - DebrisClone.Position) * 0.2 + DebrisClone.Position)
							end
						end
						task.spawn(ObsDestroyEffect,Obstacle:GetPivot().Position, 5)
						Obstacle:Destroy()
						TouchedObstacles[Obstacle] = nil
						CenterPart:ApplyImpulse(CenterPart.AssemblyLinearVelocity * CenterPart.AssemblyMass * -VehicleDamage / RawVehicleDamage * Vector3.new(1, 0, 1))
					else
						TouchedObstacles[Obstacle].Health -= VehicleDamage
					end
					
					CurrentHealth = math.max(CurrentHealth - ObstacleDamage, 0)
					
					if CurrentHealth > 0 then
						game.ReplicatedStorage.RemoteEvents.DamageCreation:FireServer(CenterPart, ObstacleDamage)
					end
				end
			end
		end
		
		if CurrentHealth > 0 and Player.Character.Humanoid.SeatPart == SeatPart then
			local Throttle = SeatPart.ThrottleFloat
			local Steer = CurrentSteerAmount
			local MaxDriveSpeed = EnginePower * 5
			local DisplayDriveSpeed = math.abs(CurrentDriveVelocity * (1 + math.noise(os.clock() * 0.6) * 0.1))
			local speedRatio = math.clamp(DisplayDriveSpeed / (MaxDriveSpeed * 1.2 + 10), 0, 1)
			local targetFOV = math.lerp(NormalFOV, MaxFOV, speedRatio)
			local TurnRadius = 0
			local DriveForce = 0
			local DriveTraction = 0
			local HasWheelNearGround = false
			local MinWheelX = 0
			local MaxWheelX = 0
			local MinWheelZ = 0
			local MaxWheelZ = 0
			local WheelbaseLength = MaxWheelbaseLength
			local WheelbaseWidth = MaxWheelbaseWidth
			
			Camera.FieldOfView = math.lerp(Camera.FieldOfView, targetFOV, Dt * 8)

			WheelOverlapParams.FilterDescendantsInstances = {workspace.PlayerCreations:FindFirstChild(Player.Name), Player.Character}
			TargetSteerAmount = (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0) + (UserInputService:IsKeyDown(Enum.KeyCode.D) and -1 or 0)
			CurrentSteerAmount += math.sign(TargetSteerAmount - CurrentSteerAmount) * math.min(math.abs(TargetSteerAmount - CurrentSteerAmount), SteerSpeed * Dt)
			TurnRadius = TurnRadiusFactor / CurrentSteerAmount / SteerFactor

			if #Wheels > 0 then
				DriveForce = (EnginePower / (#Wheels * 0.8)) * 5000
			end

			for Index, WheelInfo in Wheels do
				if WheelInfo.Wheel:IsDescendantOf(workspace) and WheelInfo.Wheel:FindFirstChild("BlockRoot") and WheelInfo.Wheel:FindFirstChild("SuspensionRoot") and WheelInfo.Wheel:FindFirstChild("WheelHitbox") and WheelInfo.Wheel:FindFirstChild("Drive") and WheelInfo.Wheel.SuspensionRoot:FindFirstChild("SteerAttachment") and WheelInfo.Wheel.BlockRoot.AssemblyRootPart == SeatPart.AssemblyRootPart then
					local SteerAngle = GetSteerAngle(WheelInfo.WheelOffset, TurnRadius)
					local OverlappingWheel = nil
					local NearWheel = nil

					WheelDetectionPart.CFrame = WheelInfo.Wheel.WheelHitbox.CFrame
					WheelDetectionPart.Size = WheelInfo.Wheel.WheelHitbox.Size * 1.2
					OverlappingWheel = workspace:GetPartsInPart(WheelDetectionPart, WheelOverlapParams)
					WheelDetectionPart.Size = WheelInfo.Wheel.WheelHitbox.Size * 3.2
					NearWheel = workspace:GetPartsInPart(WheelDetectionPart, WheelOverlapParams)

					if CurrentFuel > 0 then
						WheelInfo.Wheel.Drive.MotorMaxTorque = DriveForce * WheelInfo.WheelRadius * (0.2 + math.abs(Throttle) * 0.8)
						WheelInfo.Wheel.Drive.AngularVelocity = Throttle * MaxDriveSpeed / WheelInfo.WheelRadius
						CurrentFuel -= math.max(math.abs(Throttle), 0.05) * EnginePower * 0.05 * Dt
					else
						WheelInfo.Wheel.Drive.MotorMaxTorque = 1000
						WheelInfo.Wheel.Drive.AngularVelocity = 0
					end

					if #OverlappingWheel > 0 then
						local WheelTraction = WheelInfo.Wheel:GetAttribute("WheelTraction") or 0

						DriveTraction += WheelTraction

						if not MinWheelX or WheelInfo.WheelOffset.X < MinWheelX then
							MinWheelX = WheelInfo.WheelOffset.X
						end

						if not MaxWheelX or WheelInfo.WheelOffset.X > MaxWheelX then
							MaxWheelX = WheelInfo.WheelOffset.X
						end

						if not MinWheelZ or WheelInfo.WheelOffset.Z < MinWheelZ then
							MinWheelZ = WheelInfo.WheelOffset.Z
						end

						if not MaxWheelZ or WheelInfo.WheelOffset.Z > MaxWheelZ then
							MaxWheelZ = WheelInfo.WheelOffset.Z
						end
					end

					HasWheelNearGround = #NearWheel > 0
					WheelInfo.Wheel.SuspensionRoot.SteerAttachment.CFrame = CFrame.fromEulerAnglesYXZ(0, -SteerAngle, math.rad(-90))
				else
					Wheels[Index] = nil
				end
			end

			if MinWheelX ~= MaxWheelX then
				MaxWheelbaseWidth = math.max(MaxWheelbaseWidth, MaxWheelX - MinWheelX)
				WheelbaseWidth = MaxWheelX - MinWheelX
			end

			if MinWheelZ ~= MaxWheelZ then
				MaxWheelbaseLength = math.max(MaxWheelbaseLength, MaxWheelZ - MinWheelZ)
				WheelbaseLength = MaxWheelZ - MinWheelZ
			end

			if CurrentSteerAmount == 0 then
				SteerWeld.C0 = CFrame.new()
			else
				SteerWeld.C0 = CFrame.new(-TurnRadius, 0, 0)
			end

			GyroX.D = 2000
			GyroY.D = 10000
			GyroZ.D = 500
			GyroX.MaxTorque = Vector3.new(math.abs(CurrentDriveVelocity) * WheelbaseLength * 0.01, 0, 0)
			GyroY.MaxTorque = Vector3.new(0, 0.004, 0)
			GyroZ.MaxTorque = Vector3.new(0, 0, math.abs(CurrentDriveVelocity) * WheelbaseWidth * 0.02)
			SteerForce.AngularVelocity = Vector3.new(0, CurrentDriveVelocity / TurnRadius, 0)
			SteerForce.MaxTorque = Vector3.new(0, (DriveTraction + 1) * 2000 * math.abs(TurnRadius), 0)
			FlipForce.AngularVelocity = Vector3.new(Throttle * MaxFlipSpeed / (1 + 10 ^ (0.01 * (200 - CenterPart.AssemblyLinearVelocity.Magnitude))), 0, 0)
			FlipForce.MaxTorque = not HasWheelNearGround and CenterPart.AssemblyLinearVelocity.Magnitude * 5000 or 0
			LateralForce.MaxForce = (DriveTraction + 1) * CenterPart.AssemblyMass * 100
			Player.PlayerGui.MainGui.ScreenLeft.DrivingStats.Visible = true
			Player.PlayerGui.MainGui.ScreenCenter.DrivingStats.Visible = true
			Player.PlayerGui.MainGui.ScreenLeft.DrivingStats.FuelBar.Bar.Size = UDim2.new(TotalFuel > 0 and CurrentFuel / TotalFuel or 0, 0, 1, 0)
			Player.PlayerGui.MainGui.ScreenLeft.DrivingStats.HealthBar.Bar.Size = UDim2.new(CurrentHealth, 0, 1, 0)
			Player.PlayerGui.MainGui.ScreenCenter.DrivingStats.SpeedBar.Bar.Size = UDim2.new(math.lerp(Player.PlayerGui.MainGui.ScreenCenter.DrivingStats.SpeedBar.Bar.Size.X.Scale, speedRatio, Dt * 8), 0, 1, 0)
			Player.PlayerGui.MainGui.ScreenCenter.DrivingStats.SpeedBar.Speed.Text = math.round(DisplayDriveSpeed) .. " studs/s"
		else
			if CurrentHealth <= 0 then
				game.ReplicatedStorage.RemoteEvents.ExplodeCreation:FireServer(Player)
				VehicleDestroyed = true
			end
			
			Player.PlayerGui.MainGui.ScreenLeft.DrivingStats.Visible = false
			Player.PlayerGui.MainGui.ScreenCenter.DrivingStats.Visible = false
			Camera.FieldOfView = math.lerp(Camera.FieldOfView, NormalFOV, Dt * 6)
		end
	else
		if Player.PlayerGui:FindFirstChild("MainGui") then
			Player.PlayerGui.MainGui.ScreenLeft.DrivingStats.FuelBar.Bar.Size = UDim2.new(1, 0, 1, 0)
			Player.PlayerGui.MainGui.ScreenLeft.DrivingStats.HealthBar.Bar.Size = UDim2.new(1, 0, 1, 0)
			Player.PlayerGui.MainGui.ScreenCenter.DrivingStats.SpeedBar.Bar.Size = UDim2.new(0, 0, 1, 0)
			Player.PlayerGui.MainGui.ScreenCenter.DrivingStats.SpeedBar.Speed.Text = "0 studs/s"
		end
	end
end)

game.ReplicatedStorage.RemoteFunctions.VehicleSetup.OnClientInvoke = function(SP, CP, CW, SW, SF, FF, LF, W, HP, GX, GY, GZ, TRF, EP, TF, TS)
	if HP ~= nil then
		SeatPart = SP
		CenterPart = CP
		CenterWeld = CW
		SteerWeld = SW
		SteerForce = SF
		FlipForce = FF
		LateralForce = LF
		Wheels = W
		HitboxPart = HP
		GyroX = GX
		GyroY = GY
		GyroZ = GZ
		TurnRadiusFactor = TRF
		EnginePower = EP
		TotalFuel = TF
		TotalStrength = TS
		CurrentHealth = 1
		CurrentFuel = TotalFuel
		VehicleDestroyed = false
		TouchedObstacles = {}
		return true
	else
		return false
	end
end

ObstacleOverlapParams.FilterType = Enum.RaycastFilterType.Include
ObstacleOverlapParams.RespectCanCollide = true
ObstacleOverlapParams.Tolerance = 0.05
WheelOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
WheelOverlapParams.RespectCanCollide = true
WheelOverlapParams.Tolerance = 0.05
WheelDetectionPart.Parent = workspace.MiscStorage
WheelDetectionPart.Name = "WheelDetectionPart"
WheelDetectionPart.Transparency = 1
WheelDetectionPart.CanCollide = false
WheelDetectionPart.CanTouch = false
WheelDetectionPart.CanQuery = false
WheelDetectionPart.Anchored = true
WheelDetectionPart.Shape = Enum.PartType.Cylinder

--[[local Obstacles = {}
local loadedChunks = {}
local function UpdHitboxes()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {Obstacles}
	params.MaxParts = 200
	local NearbyObstacles = workspace:GetPartBoundsInRadius(SeatPart.Position,120,params)

	for _, part in NearbyObstacles do
		local obstacle = part.Parent
		if obstacle:FindFirstChild("Hitbox") and obstacle:FindFirstChild("Collider") then
			local vel = SeatPart.AssemblyLinearVelocity
			obstacle.Hitbox.CFrame = CFrame.new(obstacle:GetPivot().Position -vel/10) * obstacle:GetPivot().Rotation
		end
	end
end
workspace.GeneratedMap.Beginning.Obstacles.ChildAdded:Connect(function(Obstacle)
	if Obstacle:IsA("Model") then
		table.insert(Obstacles,Obstacle)
	end
end)
workspace.GeneratedMap.ChildAdded:Connect(function(Chunk)
	if not loadedChunks[Chunk] and Chunk:FindFirstChild("Obstacles") then
		loadedChunks[Chunk] = true
		Chunk.Obstacles.ChildAdded:Connect(function(Obstacle)
			if Obstacle:IsA("Model") then
				table.insert(Obstacles,Obstacle)
			end
		end)
	end
end)]]

function ObsDestroyEffect(worldPosition, money)
	local player = game.Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local effectsFolder = playerGui:WaitForChild("Effects")
print("effect")
	local guiElements = game.ReplicatedStorage:WaitForChild("GuiElements")
	local destroyEffectTemplate = guiElements:WaitForChild("DestroyEffect")

	local viewportPoint, onScreen = Camera:WorldToViewportPoint(worldPosition)
	if not onScreen then
		return
	end

	local vx = viewportPoint.X / Camera.ViewportSize.X
	local vy = viewportPoint.Y / Camera.ViewportSize.Y
	vx = math.clamp(vx, 0, 1)
	vy = math.clamp(vy, 0, 1)
	local startPos = UDim2.new(vx, 0, vy, 0)

	local effect = destroyEffectTemplate:Clone()
	effect.Parent = effectsFolder
	effect.Visible = true
	effect.AnchorPoint = Vector2.new(0.5, 0.5)
	effect.Position = startPos

	local label = effect:FindFirstChildWhichIsA("TextLabel")
	local stroke
	if label then
		label.Text = "$" .. tostring(money)
		label.TextTransparency = 0
		stroke = label:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Transparency = 0
		end
	end

	effect.Size = UDim2.new(0, 0, 0, 0)
	effect:TweenSize(UDim2.new(0, 200, 0, 200), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3, true)

	local floatAmountScale = 0.05
	local targetY = math.clamp(vy - floatAmountScale, 0, 1)
	local floatTween = TweenService:Create(
		effect,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(vx, 0, targetY, 0) }
	)
	floatTween:Play()

	task.delay(0.3, function()
		local fadeInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if label then
			TweenService:Create(label, fadeInfo, { TextTransparency = 1 }):Play()
		end
		if stroke then
			TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
		end
	end)

	game.Debris:AddItem(effect, 1.5)
end