--!strict
-- Made by blender/bow_animation.py: don't edit by hand, run the script.
-- The bow shots the game picks from after you tap. Chance is a percentage;
-- ReleaseAt is when the egg leaves (seconds into the animation); Pull is the
-- string's draw over time, as { time, amount }; Spin (if any) is when the
-- follow-through spin starts and how long it takes.

export type Shot = {
	Name: string,
	Chance: number,
	Length: number,
	ReleaseAt: number,
	Pull: { { number } },
	Spin: { number }?,
}

local ShotAnimations: { Shot } = {
	{
		Name = "BowShot1",
		Chance = 70,
		Length = 3,
		ReleaseAt = 2.3,
		Pull = { { 0, 0 }, { 0.45, 0 }, { 0.7, 0.6 }, { 1.1, 0.74 }, { 1.5, 0.88 }, { 1.85, 1 }, { 2.3, 1 } },
		Spin = nil,
	},
	{
		Name = "BowShot2",
		Chance = 30,
		Length = 3.6,
		ReleaseAt = 2.5,
		Pull = { { 0, 0 }, { 0.35, 0 }, { 0.55, 0.6 }, { 0.95, 0.8 }, { 1.35, 0.95 }, { 1.75, 1 }, { 2.5, 1 } },
		Spin = { 2.7, 0.36 },
	},
}

return ShotAnimations
