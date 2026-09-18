package foxlite.animation;

import foxlite.animation.FoxEaseType;

class FoxKeyframe<T> {
	public var time:Float;
	public var ease:FoxEaseType;
	public var value:T;

	public function new(time_:Float, value_:T, easing:FoxEaseType) {
		// Polymod doesn't like this.<property> in the constructor
		time = time_;
		value = value_;
		ease = easing;
	}
}