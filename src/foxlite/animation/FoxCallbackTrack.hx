package foxlite.animation;

import haxe.ds.StringMap;
import foxlite.animation.FoxAnimationTrack;

abstract FoxTrackCall(Array<Dynamic>) {
	public function new(name:String, ?arguments:Array<Dynamic>) {
		this = [name, arguments ?? []];
	}
}

/**
	This is a variation of FoxAnimationTrack that allows for calling a keyframe as a function.
**/
class FoxCallbackTrack extends FoxAnimationTrack<FoxTrackCall> {

	/**
		A map of callbacks used for this track.

		Add a frame following this format:
		`addFrame(<time>, [<callbackName>, [<arguments>]], ...)`
	**/
	public var callbacks:Map<String, Dynamic> = new StringMap();
}