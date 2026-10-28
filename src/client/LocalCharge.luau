--!strict
-- The local player's charge, written by ChargeController and read by
-- PoseController, so your own arms move the instant you press, without waiting
-- for the server. Times are os.clock().

local LocalCharge = {
	charging = false,
	startedAt = 0,
	releasedAt = -math.huge,
	releasePull = 0,
}

return LocalCharge
