package foxlite.skin;

import foxlite.FoxModel;
import foxlite.group.FoxObjectGroup;
import foxlite.skin.FoxSkinData;

/**
	An easy way of managing armatures for model groups
**/
class FoxArmature extends FoxObjectGroup {
	
	/**
		Binds for this mesh, affects every model in this group.
	**/
	public var skin(default, set):FoxSkinData = null;

	public function new(?_skin:FoxSkinData) {
		super();
		this.skin = _skin;
		name = "FoxArmature";
	}

	/**
		Checks a model and assigns the skin bindings to it.
	**/
	public function checkModel(member:FoxObject):FoxObject {
		if(member == null) return null;
		var model:FoxModel = cast member; // Check skin
		if(Std.isOfType(model, FoxModel)) model.skin = skin;
		return member;
	}

	public override function add(member:FoxObject):FoxObject {
		member = super.add(member);
		return checkModel(member);
	}

	public override function insert(pos:Int, member:FoxObject):FoxObject {
		member = super.insert(pos, member);
		return checkModel(member);
	}
	
	public override function update(dt:Float) {
		super.update(dt);
		if(skin != null) {
			skin.root.transform = this.transform;
			skin.update(dt);
		}
	}

	private function set_skin(v:FoxSkinData):FoxSkinData {
		if(this.skin == v) return v;
		this.skin = v;
		forEach(m -> this.checkModel(m));
		return v;
	}
}