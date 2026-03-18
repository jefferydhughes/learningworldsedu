--- This module helps creating and using passkeys.

mod = {}
-- TODO: gaetan: should we use a metatable for the module table?

-- import modules
system_api = require("system_api", System)

mod.isSupported = function(self)
	if self ~= mod then
		error("passkey:isSupported(): use `:`", 2)
	end
	return System.PasskeySupported
end

-- Gets a passkey challenge for the current user from the API server.
-- Arguments:
-- - callback(challenge, error): a function that will be called with the passkey challenge)
-- Callback signature: func(challenge, error)
-- challenge: string
-- error: nil on success, error message (string) on failure
mod.getChallenge = function(self, callback)
	if self ~= mod then
		error("passkey.getChallenge(): use `:`", 2)
	end

	if not self:isSupported() then
		callback(nil, "passkey is not supported on this device")
		return
	end

	-- Make sure the current user has a userID and a username
	if System.UserID == nil then
		callback(nil, "current user has no userID ")
		return
	end
	if System.Username == nil then
		callback(nil, "current user has no username")
		return
	end

	-- Get a passkey challenge from the server
	system_api:getPasskeyChallenge(function(challenge, error)
		if error ~= nil then
			callback(nil, error)
			return
		end

		-- Success.
		-- Return the challenge.
		callback(challenge, nil)
	end)
end

-- Prompts the user to create a passkey using the native passkey creation dialog.
-- Arguments:
-- - challenge: the challenge to create the passkey with
-- - callback(publicKey, error): a function that will be called with the public key if the passkey creation succeeds, or an error if it fails
mod.createPasskey = function(self, challenge, callback)
	if self ~= mod then
		error("passkey.createPasskey(): use `:`", 2)
	end

	if not self:isSupported() then
		callback(nil, "passkey is not supported on this device")
		return
	end

	-- Make sure the current user has a userID and a username
	if System.UserID == nil then
		callback(nil, "current user has no userID ")
		return
	end
	if System.Username == nil then
		callback(nil, "current user has no username")
		return
	end
	-- Make sure the challenge is not nil or an empty string
	if challenge == nil or challenge == "" then
		callback(nil, "challenge is nil or empty")
		return
	end

	-- Create the passkey
	System:PasskeyCreate(System.UserID, challenge, System.Username, function(publicKey, err)
		if err ~= nil then
			callback(nil, err)
			return
		end

		-- Success.
		-- Return the public key.
		callback(publicKey, nil)
	end)
end

return mod
