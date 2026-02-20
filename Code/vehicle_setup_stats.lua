local function getAABB(Model, RoundIncrement)
    local cf = Model:GetPivot()
	local dimensions = Model:GetAttribute("BlockDimensions")

	if not dimensions then
		return nil
	end

	local halfSize = dimensions / 2
	local corners = {
		Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
		Vector3.new(halfSize.X, -halfSize.Y, -halfSize.Z),
		Vector3.new(-halfSize.X, halfSize.Y, -halfSize.Z),
		Vector3.new(halfSize.X, halfSize.Y, -halfSize.Z),
		Vector3.new(-halfSize.X, -halfSize.Y, halfSize.Z),
		Vector3.new(halfSize.X, -halfSize.Y, halfSize.Z),
		Vector3.new(-halfSize.X, halfSize.Y, halfSize.Z),
		Vector3.new(halfSize.X, halfSize.Y, halfSize.Z),
	}

	local worldCorners = {}
	for i, corner in ipairs(corners) do
		worldCorners[i] = cf:PointToWorldSpace(corner)
	end

	local minBound = worldCorners[1]
	local maxBound = worldCorners[1]

	for i = 2, #worldCorners do
		local corner = worldCorners[i]
		minBound = Vector3.new(
			math.min(minBound.X, corner.X),
			math.min(minBound.Y, corner.Y),
			math.min(minBound.Z, corner.Z)
		)
		maxBound = Vector3.new(
			math.max(maxBound.X, corner.X),
			math.max(maxBound.Y, corner.Y),
			math.max(maxBound.Z, corner.Z)
		)
	end

	local function roundToIncrement(value, increment)
		return math.floor(value / increment + 0.5) * increment
	end

	minBound = Vector3.new(
		roundToIncrement(minBound.X, RoundIncrement),
		roundToIncrement(minBound.Y, RoundIncrement),
		roundToIncrement(minBound.Z, RoundIncrement)
	)
	maxBound = Vector3.new(
		roundToIncrement(maxBound.X, RoundIncrement),
		roundToIncrement(maxBound.Y, RoundIncrement),
		roundToIncrement(maxBound.Z, RoundIncrement)
	)

	return {Min = minBound, Max = maxBound}
end

local function aabbsIntersectOrAdjacent(Box1, Box2, Tolerance)
	Tolerance = Tolerance or 0.01

	if Box1.Max.X < Box2.Min.X - Tolerance or Box2.Max.X < Box1.Min.X - Tolerance then
		return false
	end
	if Box1.Max.Y < Box2.Min.Y - Tolerance or Box2.Max.Y < Box1.Min.Y - Tolerance then
		return false
	end
	if Box1.Max.Z < Box2.Min.Z - Tolerance or Box2.Max.Z < Box1.Min.Z - Tolerance then
		return false
	end

	local touchingFaces = 0

	if math.abs(Box1.Max.X - Box2.Min.X) <= Tolerance or math.abs(Box2.Max.X - Box1.Min.X) <= Tolerance then
		touchingFaces = touchingFaces + 1
	end

	if math.abs(Box1.Max.Y - Box2.Min.Y) <= Tolerance or math.abs(Box2.Max.Y - Box1.Min.Y) <= Tolerance then
		touchingFaces = touchingFaces + 1
	end

	if math.abs(Box1.Max.Z - Box2.Min.Z) <= Tolerance or math.abs(Box2.Max.Z - Box1.Min.Z) <= Tolerance then
		touchingFaces = touchingFaces + 1
	end

	return touchingFaces <= 1
end

local function sumConnectedModels(StartModel, AllModels, RoundIncrement, AttributeName)
	RoundIncrement = RoundIncrement or 0.1

	local Visited = {}
	local queue = {StartModel}
	local totalValue = 0

	local aabbCache = {}
	for _, model in ipairs(AllModels) do
		if model:IsA("Model") and model:GetAttribute("BlockDimensions") then
			aabbCache[model] = getAABB(model, RoundIncrement)
		end
	end

	while #queue > 0 do
		if #queue % 200 == 0 then
			task.wait()
		end
		local currentModel = table.remove(queue, 1)

		if Visited[currentModel] then
			continue
		end

		Visited[currentModel] = true

		local value = currentModel:GetAttribute(AttributeName)
		if value and type(value) == "number" then
			totalValue = totalValue + value
		end

		local currentAABB = aabbCache[currentModel]
		if not currentAABB then
			continue
		end

		for _, otherModel in AllModels do
			if not Visited[otherModel] and otherModel ~= currentModel then
				local otherAABB = aabbCache[otherModel]

				if otherAABB and aabbsIntersectOrAdjacent(currentAABB, otherAABB) then
					table.insert(queue, otherModel)
				end
			end
		end
	end

	return totalValue, Visited
end

function UpdatePlayerCreationStats(Player)
	local TotalFuel = 0
	local TotalPower = 0
	local TotalStrength = 0
	
	if PlayerInfo[Player].Status == "Building" then
		local CreationFolder = workspace.PlayerCreations:FindFirstChild(Player.Name)

		if CreationFolder and CreationFolder:FindFirstChild("1") and CreationFolder["1"]:GetAttribute("BlockFunction") and CreationFolder["1"]:GetAttribute("BlockFunction") == "Driver Seat" then
			TotalFuel = sumConnectedModels(CreationFolder["1"], CreationFolder:GetChildren(), 0.1, "Capacity")
			TotalPower = sumConnectedModels(CreationFolder["1"], CreationFolder:GetChildren(), 0.1, "EnginePower")
			TotalStrength = sumConnectedModels(CreationFolder["1"], CreationFolder:GetChildren(), 0.1, "Strength")
		end
		
		game.ReplicatedStorage.RemoteEvents.UpdateCreationStats:FireClient(Player, TotalFuel, TotalPower, TotalStrength)
	end
end

function SetupCreation(Player, CreationFolder)
	local CreationFolder = workspace.PlayerCreations:FindFirstChild(Player.Name)
	local BaseParts = {}
	local HitboxParts = {}
	local Unanchored = 0
	local SeatPart = nil
	
	for _, Descendant in CreationFolder:GetDescendants() do
		if Descendant:IsA("BasePart") then
			local PartMass = Descendant:GetAttribute("PartMass")

			table.insert(BaseParts, Descendant)

			if PartMass then
				SetPhysicalProperty(Descendant, "Density", PartMass * Descendant.CurrentPhysicalProperties.Density / Descendant.Mass)
			else
				Descendant.Massless = true
			end

			if Descendant:HasTag("BlockRoot") then
				Descendant.FrontSurface = Enum.SurfaceType.Universal
				Descendant.BackSurface = Enum.SurfaceType.Universal
				Descendant.LeftSurface = Enum.SurfaceType.Universal
				Descendant.RightSurface = Enum.SurfaceType.Universal
				Descendant.TopSurface = Enum.SurfaceType.Universal
				Descendant.BottomSurface = Enum.SurfaceType.Universal
				Descendant:MakeJoints()
			end
			
			if Descendant:IsA("VehicleSeat") and Descendant.Parent:GetAttribute("BlockFunction") and Descendant.Parent:GetAttribute("BlockFunction") == "Driver Seat" then
				SeatPart = Descendant
			end
		end
	end
	
	for _, BasePart in BaseParts do
		if BasePart ~= SeatPart then
			if Unanchored % BulkSetupAmount == 0 then
				task.wait()
			end

			BasePart.Anchored = false
			Unanchored += 1
		end
	end
	
	if SeatPart then
		local Wheels = {}
		local TotalFuel = 0
		local TotalStrength = 0
		local EnginePower = 0
		local CenterPoint = Vector3.new()
		local WheelWeightSum = 0
		local MiddleWheelYSum = 0
		local BottomWheelYSum = 0
		local WheelXSum = 0
		local WheelZSum = 0
		local WheelMinZ = SeatPart.Position.Z
		local WheelMaxZ = SeatPart.Position.Z
		local WheelMinX = nil
		local WheelMaxX = nil
		
		for _, Child in CreationFolder:GetChildren() do
			if Child:IsA("Model") and Child:GetAttribute("BlockFunction") and Child:FindFirstChild("BlockRoot") and Child.BlockRoot.AssemblyRootPart == SeatPart.AssemblyRootPart then
				local BlockStrength = Child:GetAttribute("Strength")
				
				if Child:GetAttribute("BlockFunction") == "Wheel" then
					local Position = Child:GetPivot().Position
					local WheelTraction = Child:GetAttribute("WheelTraction") and math.clamp(Child:GetAttribute("WheelTraction"), 0, 1) or 0.4
					local Dimensions = Child:GetAttribute("BlockDimensions") or Vector3.new(2, 2, 2)
					
					table.insert(Wheels, {Wheel = Child})
					Child:SetAttribute("WheelTraction", WheelTraction)
					WheelWeightSum += Dimensions.X + Dimensions.Y + Dimensions.Z
					WheelXSum += Position.X * (Dimensions.X + Dimensions.Y + Dimensions.Z)
					MiddleWheelYSum += (Position.Y) * (Dimensions.X + Dimensions.Y + Dimensions.Z)
					BottomWheelYSum += (Position.Y - Dimensions.Y / 2) * (Dimensions.X + Dimensions.Y + Dimensions.Z)
					WheelZSum += Position.Z * (Dimensions.X + Dimensions.Y + Dimensions.Z)
					
					if not WheelMinX or Position.X < WheelMinX then
						WheelMinX = Position.X
					end

					if not WheelMaxX or Position.X > WheelMaxX then
						WheelMaxX = Position.X
					end
					
					if not WheelMinZ or Position.Z < WheelMinZ then
						WheelMinZ = Position.Z
					end

					if not WheelMaxZ or Position.Z > WheelMaxZ then
						WheelMaxZ = Position.Z
					end

					if Child:FindFirstChild("WheelHitbox") then
						SetPhysicalProperty(Child.WheelHitbox, "Friction", WheelTraction * 2)
						SetPhysicalProperty(Child.WheelHitbox, "Elasticity", 0)
						SetPhysicalProperty(Child.WheelHitbox, "FrictionWeight", 100)
						SetPhysicalProperty(Child.WheelHitbox, "ElasticityWeight", 100)
					end

					if Child:FindFirstChild("SuspensionRoot") and Child.BlockRoot:FindFirstChild("Suspension") and Child.BlockRoot:FindFirstChild("SuspensionAttachment") then
						local LimitAttachment = Instance.new("Attachment")
						local SuspensionLimit = Instance.new("RopeConstraint")
						
						LimitAttachment.Parent = Child.SuspensionRoot
						LimitAttachment.Name = "LimitAttachment"
						LimitAttachment.WorldPosition = Child.BlockRoot.SuspensionAttachment.WorldPosition + Vector3.new(0, Child.BlockRoot.Suspension.FreeLength / 2 - Child.BlockRoot.Suspension.CurrentLength + 0.5, 0)
						SuspensionLimit.Parent = Child.BlockRoot
						SuspensionLimit.Name = "SuspensionLimit"
						SuspensionLimit.Visible = false
						SuspensionLimit.Attachment0 = Child.BlockRoot.SuspensionAttachment
						SuspensionLimit.Attachment1 = LimitAttachment
						SuspensionLimit.Length = Child.BlockRoot.Suspension.FreeLength / 2
					end

					if Child:FindFirstChild("Drive") then
						Child.Drive.MotorMaxTorque = 0
					end
				elseif Child:GetAttribute("BlockFunction") == "Engine" then
					local Power = Child:GetAttribute("EnginePower")

					if Power then
						EnginePower += Power
					end
				elseif Child:GetAttribute("BlockFunction") == "Fuel" then
					local Fuel = Child:GetAttribute("Capacity")

					if Fuel then
						TotalFuel += Fuel
					end
				end
				
				table.insert(HitboxParts, Child.BlockRoot)
				
				if Child:GetAttribute("BlockFunction") == "Wheel" and Child:FindFirstChild("WheelHitbox") then
					table.insert(HitboxParts, Child.WheelHitbox)
				end
				
				if BlockStrength then
					TotalStrength += BlockStrength
				end
			else
				for _, Descendant in Child:GetDescendants() do
					if Descendant:IsA("BasePart") then
						Descendant.Massless = false
						Descendant.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0, 1, 100, 100)
						Descendant.Transparency = 1 - ((1 - Descendant.Transparency) * 0.6)
						Descendant.Color = Color3.fromRGB(Descendant.Color.R * 255 * 2, Descendant.Color.G * 255, Descendant.Color.B * 255)
						Descendant.Material = Enum.Material.Glass
						Descendant.AssemblyLinearVelocity = Vector3.new(0,10,0)
					elseif Descendant:IsA("Constraint") then
						Descendant:Destroy()
					end
				end
			end
		end
		
		if #HitboxParts > 0 then
			local VerticalCenterOffset = 0
			local CenterPart = Instance.new("Part")
			local SteerPart = Instance.new("Part")
			local CenterWeld = Instance.new("Weld")
			local SteerWeld = Instance.new("Weld")
			local BottomAttachment = Instance.new("Attachment")
			local CenterAttachment = Instance.new("Attachment")
			local SteerForce = Instance.new("BodyAngularVelocity")
			local FlipForce = Instance.new("AngularVelocity")
			local GyroPartX = Instance.new("Part")
			local GyroPartY = Instance.new("Part")
			local GyroPartZ = Instance.new("Part")
			local GyroWeldX = Instance.new("Weld")
			local GyroWeldY = Instance.new("Weld")
			local GyroWeldZ = Instance.new("Weld")
			local GyroX = Instance.new("BodyGyro")
			local GyroY = Instance.new("BodyGyro")
			local GyroZ = Instance.new("BodyGyro")
			local LateralForce = Instance.new("LinearVelocity")
			local TurnRadiusFactor = 0
			local VehicleHitbox = nil
			
			if WheelMinZ and WheelMaxZ then
				TurnRadiusFactor = math.max(WheelMaxZ - WheelMinZ, 12)
			end
			
			CenterPoint = Vector3.new(WheelWeightSum > 0 and WheelXSum / WheelWeightSum or SeatPart.AssemblyCenterOfMass.X, WheelWeightSum > 0 and MiddleWheelYSum / WheelWeightSum or SeatPart.AssemblyCenterOfMass.Y, WheelWeightSum > 0 and WheelZSum / WheelWeightSum or SeatPart.AssemblyCenterOfMass.Z)
			CenterWeld.C0 = SeatPart.CFrame:ToObjectSpace(CFrame.new(CenterPoint))
			VerticalCenterOffset = SeatPart.AssemblyCenterOfMass.Y - CenterPoint.Y

			for _, WheelInfo in Wheels do
				local WheelHitboxSize = WheelInfo.Wheel:FindFirstChild("WheelHitbox") and WheelInfo.Wheel:FindFirstChild("WheelHitbox").Size or Vector3.new(0, 2, 2)
				
				if WheelInfo.Wheel.BlockRoot:FindFirstChild("Suspension") then
					WheelInfo.Wheel.BlockRoot.Suspension.Damping *= 4 / #Wheels
					WheelInfo.Wheel.BlockRoot.Suspension.Stiffness *= (4 / #Wheels * 0.6) + 0.4
					WheelInfo.Wheel.BlockRoot.Suspension.FreeLength += 0.8
				end

				WheelInfo.WheelRadius = math.min(WheelHitboxSize.Y, WheelHitboxSize.Z) / 2
				WheelInfo.WheelOffset = WheelInfo.Wheel:GetPivot().Position - Vector3.new(CenterPoint.X, CenterPoint.Y, CenterPoint.Z * 0.6 + WheelMaxZ * 0.4)
			end

			if #HitboxParts > 1 then
				VehicleHitbox = table.remove(HitboxParts, 1):UnionAsync(HitboxParts, Enum.CollisionFidelity.Hull, Enum.RenderFidelity.Performance)
			else
				VehicleHitbox = HitboxParts[1]:Clone()
				VehicleHitbox:ClearAllChildren()
			end
			
			CenterPart.Parent = SeatPart
			CenterPart.Name = "CenterPart"
			CenterPart.Transparency = 1
			CenterPart.Size = Vector3.new(10, 10, 10)
			CenterPart.CanCollide = false
			CenterPart.CanQuery = false
			CenterPart.CanTouch = false
			CenterPart.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
			SteerPart.Parent = SeatPart
			SteerPart.Name = "SteerPart"
			SteerPart.Transparency = 1
			SteerPart.Size = Vector3.new(1, 1, 1)
			SteerPart.CanCollide = false
			SteerPart.CanQuery = false
			SteerPart.CanTouch = false
			SteerPart.Massless = true
			BottomAttachment.Parent = CenterPart
			BottomAttachment.Name = "BottomAttachment"
			BottomAttachment.CFrame = CFrame.new(0, (WheelWeightSum > 0 and (BottomWheelYSum / WheelWeightSum - MiddleWheelYSum / WheelWeightSum) * (1 - math.min((WheelMaxX - WheelMinX) / 12, 1)) or 0), 0)
			CenterAttachment.Parent = CenterPart
			CenterAttachment.Name = "CenterAttachment"
			CenterAttachment.CFrame = CFrame.new(0, VerticalCenterOffset, 0)
			CenterWeld.Parent = SeatPart
			CenterWeld.Name = "CenterWeld"
			CenterWeld.Part0 = SeatPart
			CenterWeld.Part1 = CenterPart
			SteerWeld.Parent = CenterPart
			SteerWeld.Name = "SteerWeld"
			SteerWeld.Part0 = CenterPart
			SteerWeld.Part1 = SteerPart
			SteerForce.Parent = SteerPart
			SteerForce.Name = "SteerForce"
			SteerForce.P = 1000
			FlipForce.Parent = CenterPart
			FlipForce.Name = "FlipForce"
			FlipForce.Attachment0 = CenterAttachment
			FlipForce.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			GyroPartX.Parent = SeatPart
			GyroPartX.Name = "GyroPartX"
			GyroPartX.Transparency = 1
			GyroPartX.Size = Vector3.new(1, 1, 1)
			GyroPartX.CanCollide = false
			GyroPartX.CanQuery = false
			GyroPartX.CanTouch = false
			GyroPartX.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
			GyroWeldX.Parent = CenterPart
			GyroWeldX.Name = "GyroWeldX"
			GyroWeldX.Part0 = CenterPart
			GyroWeldX.Part1 = GyroPartX
			GyroX.Parent = GyroPartX
			GyroX.Name = "GyroX"
			GyroX.P = 1000
			GyroPartY.Parent = SeatPart
			GyroPartY.Name = "GyroPartY"
			GyroPartY.Transparency = 1
			GyroPartY.Size = Vector3.new(1, 1, 1)
			GyroPartY.CanCollide = false
			GyroPartY.CanQuery = false
			GyroPartY.CanTouch = false
			GyroPartY.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
			GyroWeldY.Parent = CenterPart
			GyroWeldY.Name = "GyroWeldY"
			GyroWeldY.Part0 = CenterPart
			GyroWeldY.Part1 = GyroPartY
			GyroY.Parent = GyroPartY
			GyroY.Name = "GyroY"
			GyroY.P = 1000
			GyroPartZ.Parent = SeatPart
			GyroPartZ.Name = "GyroPartZ"
			GyroPartZ.Transparency = 1
			GyroPartZ.Size = Vector3.new(1, 1, 1)
			GyroPartZ.CanCollide = false
			GyroPartZ.CanQuery = false
			GyroPartZ.CanTouch = false
			GyroPartZ.CustomPhysicalProperties = PhysicalProperties.new(1, 0, 0, 100, 100)
			GyroWeldZ.Parent = CenterPart
			GyroWeldZ.Name = "GyroWeldZ"
			GyroWeldZ.Part0 = CenterPart
			GyroWeldZ.Part1 = GyroPartZ
			GyroZ.Parent = GyroPartZ
			GyroZ.Name = "GyroZ"
			GyroZ.P = 1000
			LateralForce.Parent = CenterPart
			LateralForce.Name = "LateralForce"
			LateralForce.Attachment0 = BottomAttachment
			LateralForce.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
			LateralForce.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			VehicleHitbox.Parent = SeatPart
			VehicleHitbox.Name = "Hitbox"
			VehicleHitbox.Transparency = 1
			VehicleHitbox.PivotOffset = VehicleHitbox.CFrame:Inverse() * CenterPart.CFrame
			VehicleHitbox.CanCollide = false
			VehicleHitbox.Anchored = true
			
			while VehicleHitbox do
				task.wait(0.1)
				if game.ReplicatedStorage.RemoteFunctions.VehicleSetup:InvokeClient(Player, SeatPart, CenterPart, CenterWeld, SteerWeld, SteerForce, FlipForce, LateralForce, Wheels, VehicleHitbox, GyroX, GyroY, GyroZ, TurnRadiusFactor, EnginePower, TotalFuel, TotalStrength) then
					SeatPart.Anchored = false
					break
				end
			end
			
			if Player.Character and Player.Character:FindFirstChildOfClass("Humanoid") and Player.Character.Humanoid.SeatPart ~= SeatPart then
				SeatPart:Sit(Player.Character.Humanoid)
			end
		end
	else
		for _, Descendant in CreationFolder:GetDescendants() do
			if Descendant:IsA("BasePart") then
				Descendant.Massless = false
				Descendant.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0, 1, 100, 100)
				Descendant.Transparency = 1 - ((1 - Descendant.Transparency) * 0.6)
				Descendant.Color = Color3.fromRGB(Descendant.Color.R * 255 * 2, Descendant.Color.G * 255, Descendant.Color.B * 255)
				Descendant.Material = Enum.Material.Glass
				Descendant.AssemblyLinearVelocity = Vector3.new(0,10,0)
			elseif Descendant:IsA("Constraint") then
				Descendant:Destroy()
			end
		end
	end
end