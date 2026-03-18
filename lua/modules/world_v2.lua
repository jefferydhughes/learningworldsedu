local worldV2 = {}

-- Read objects chunk from data stream (for version 2)
worldV2.readChunkObjects = function(d)
	local objectsInfo = {}
	d:ReadUInt32() -- read size
	local nbObjects = d:ReadUInt16()
	local fetchedObjects = 0
	
	while fetchedObjects < nbObjects do
		local fullnameSize = d:ReadUInt16()
		local fullname = d:ReadString(fullnameSize)
		local nbInstances = d:ReadUInt16()
		
		for _ = 1, nbInstances do
			local instance = {
				fullname = fullname,
			}
			
			local nbFields = d:ReadUInt8()
			for _ = 1, nbFields do
				local key = d:ReadString(2)
				
				if key == "po" then
					instance.Position = d:ReadNumber3()
				elseif key == "ro" then
					instance.Rotation = d:ReadRotation()
				elseif key == "sc" then
					instance.Scale = d:ReadNumber3()
				elseif key == "na" then
					local nameLength = d:ReadUInt8()
					instance.Name = d:ReadString(nameLength)
				elseif key == "id" then
					local idLength = d:ReadUInt8()
					instance.uuid = d:ReadString(idLength)
				elseif key == "de" then
					local length = d:ReadUInt16()
					instance.itemDetailsCell = Data(d:ReadString(length), { format = "base64" }):ToTable()
				elseif key == "pm" then
					instance.Physics = d:ReadPhysicsMode()
				else
					error("Wrong format while deserializing", 2)
					return false
				end
			end
			
			if instance.uuid == nil then
				error("Object has no uuid")
			end
			objectsInfo[instance.uuid] = instance
			fetchedObjects = fetchedObjects + 1
		end
	end
	
	return objectsInfo, fetchedObjects
end

return worldV2
