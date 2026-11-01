--!strict
-- The local player's shot, written by ChargeController and read by
-- PoseController and ShotCamera, so your own character and camera react the
-- instant you tap, without waiting for the server. Times are os.clock().
--
-- A shot goes: charging (the meter bounces while you stand holding the bow),
-- then you tap and shooting starts (one of ShotAnimations plays: the draw, then
-- the release at its ReleaseAt), and releasedAt is the moment the egg leaves.

local LocalCharge = {
	charging = false,
	startedAt = 0,
	shooting = false, -- a shot animation is playing
	shotName = "", -- which one (ShotAnimations)
	shotStartedAt = 0, -- when you tapped
	releasedAt = -math.huge, -- when the string let go
	releasePull = 0, -- how far the string was drawn
	releaseStage = "", -- the meter stage you tapped on, e.g. "Perfect"
}

return LocalCharge
