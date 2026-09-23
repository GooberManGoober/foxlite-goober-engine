package foxlite.texture;

import StringTools;
import lime.graphics.opengl.GL;
import lime.graphics.Image;
import lime.system.ThreadPool;
import foxlite.FoxCache;
import foxlite.loaders.FoxLoaderUtil;
import foxlite.renderer.FoxRenderer;
import foxlite.texture.FoxMipFilter;
import foxlite.texture.FoxTextureFilter;
import foxlite.texture.FoxWrapMode;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.display3D.Context3D;
import openfl.display3D.Context3DTextureFormat;
import openfl.display3D.textures.TextureBase;
import openfl.display3D.textures.RectangleTexture;

class FoxTexture {
	public var context:Context3D = null;

	public var wrapMode(default, set):FoxWrapMode;
	public var filter(default, set):FoxTextureFilter;
	public var mipFilter(default, set):FoxMipFilter;
	public var glTexture:TextureBase; // Fix C++ black textures via downcast
	public var assetsKey:String;

	/**
		Wheter or not this texture is loaded

		This property also indicates wheter this texture has a valid `glTexture`,
		usually assigned when images load
	**/
	public var loaded(get, never):Bool;

	function get_loaded():Bool {
		return glTexture != null;
	}

	public var width(get, default):Int;
	public var height(get, default):Int;

	public var __paramsNeedUpdate:Bool = true;

	private function set_wrapMode(v:FoxWrapMode):FoxWrapMode {
		if(this.wrapMode == v) return v;
		__paramsNeedUpdate = true;
		return this.wrapMode = v;
	}

	private function set_filter(v:FoxTextureFilter):FoxTextureFilter {
		if(this.filter == v) return v;
		__paramsNeedUpdate = true;
		return this.filter = v;
	}

	private function set_mipFilter(v:FoxMipFilter):FoxMipFilter {
		if(this.mipFilter == v) return v;
		__paramsNeedUpdate = true;
		return this.mipFilter = v;
	}

	private function get_width():Int {
		return glTexture?.__width ?? 0;
	}

	private function get_height():Int {
		return glTexture?.__height ?? 0;
	}

	// Used to store information when resizing
	// If the texture was loaded from a file, it cannot be resized
	private var __format:String = null;
	private var __type:String = null;

	public function new(wrapMode:FoxWrapMode=#if !foxlite_polymod FoxWrapMode.CLAMP #else 0 #end, filter:FoxTextureFilter=#if !foxlite_polymod FoxTextureFilter.LINEAR #else 4 #end, mipFilter:FoxMipFilter=#if !foxlite_polymod FoxMipFilter.MIPNONE #else 2 #end) {
		FoxRenderer.allocationsThisFrame += 1;
		context = FoxRenderer.getContext();
		this.wrapMode = wrapMode;
		this.filter = filter;
		this.mipFilter = mipFilter;
	}

	public function asBitmapData():BitmapData {
		return BitmapData.fromTexture(glTexture);
	}

	// Copies this texture object, does not create new data on GPU
	public function copy():FoxTexture {
		var tex = new FoxTexture();
		tex.wrapMode = wrapMode;
		tex.filter = filter;
		tex.mipFilter = mipFilter;
		tex.glTexture = tex.glTexture;
		return tex;
	}

	public function generateMipmaps() {
		FoxRenderer.generateMipmap(context, this);
	}

	/**
		Resizes this texture. Intended for framebuffer textures,

		__Note:__ This will not work with textures that have been wrapped/loaded from a file.
	**/
	public function resize(width:Int, height:Int):FoxTexture {
		if(__format == null || __type == null) {
			trace("[FoxLite > FoxTexture]: Wrapped/Loaded textures cannot be resized!!!");
			return this;
		}
		glTexture?.dispose();
		glTexture = FoxRenderer.createTextureStorage(width, height, __format, __type);
		return this;
	}

	/**
		Instance version of `FoxTexture.wrap()`

		Takes a `BitmapData` and sets it as the GPU texture

		__Note:__ This will not update any extra information of this texture, such as format or type.
	**/
	public function take(bitmap:BitmapData) {
		if(bitmap.__texture == null) bitmap.getTexture(context);
		glTexture = bitmap.__texture;
	}

	/**
		Instance version of `FoxTexture.wrapGL()`

		Takes a `Texture` and sets it as the GPU texture

		__Note:__ This will not update any extra information of this texture, such as format or type.
	**/
	public function takeGL(texture:TextureBase) {
		glTexture = texture;
	}

	public function destroy() {
		glTexture?.dispose();
		if(assetsKey != null) FoxCache.textures().remove(assetsKey);
		glTexture = null;
	}

	public static function fromBitmapData(data:BitmapData, format:Context3DTextureFormat=#if !foxlite_polymod Context3DTextureFormat.BGRA #else 1 #end, mipmaps:Bool=false, ?params:{?wrapMode:FoxWrapMode, ?filter:FoxTextureFilter, ?mipFilter:FoxMipFilter}):FoxTexture {
		if(data == null) return null;
		// TODO: Add compressed textures
		var tex = FoxRenderer.getContext().createTexture(data.width, data.height, format, false);
		tex.uploadFromBitmapData(data, 0, mipmaps);

		var foxTex = FoxTexture.wrapGL(tex);
		if(params != null) {
			foxTex.wrapMode = params.wrapMode ?? FoxWrapMode.CLAMP;
			foxTex.filter = params.filter ?? FoxTextureFilter.LINEAR;
			foxTex.mipFilter = params.mipFilter ?? FoxMipFilter.MIPNONE;
		}
		return foxTex;
	}

	/**
		Loads a `FoxTexture` from an image located in `images/` (with .png extension)
	**/
	public static function fromImage(name:String, mipmaps:Bool=false, format:Context3DTextureFormat=#if !foxlite_polymod Context3DTextureFormat.BGRA #else 1 #end, ?params:{?wrapMode:FoxWrapMode, ?filter:FoxTextureFilter, ?mipFilter:FoxMipFilter}):FoxTexture {
		return fromImageRaw(FoxLoaderUtil.imagePath(name), mipmaps, format, params);
	}
	
	/**
		Loads a `FoxTexture` using a full raw asset path (including extension)

		This may also include compressed textures with the .dds extension
	**/
	public static function fromImageRaw(name:String, mipmaps:Bool=false, format:Context3DTextureFormat=#if !foxlite_polymod Context3DTextureFormat.BGRA #else 1 #end, ?params:{?wrapMode:FoxWrapMode, ?filter:FoxTextureFilter, ?mipFilter:FoxMipFilter}):FoxTexture {
		if(FoxCache.textures().exists(name)) return FoxCache.textures().get(name);
		
		var isDataUrl = StringTools.startsWith(name, "data:");
		if(!Assets.exists(name) && !isDataUrl) {
			trace('[Foxlite > FoxTexture]: Could not load image: ${name} (Not found.)');
			return null;
		}

		var foxTex = new FoxTexture();

		if(params != null) {
			foxTex.wrapMode = params.wrapMode ?? FoxWrapMode.CLAMP;
			foxTex.filter = params.filter ?? FoxTextureFilter.LINEAR;
			foxTex.mipFilter = params.mipFilter ?? FoxMipFilter.MIPNONE;
		}
		
		foxTex.assetsKey = name;
		trace("[FoxLite > FoxTexture]: Add texture to cache: " + (StringTools.startsWith(name, "data:") ? "<Base64URL_String>" : name));
		FoxCache.textures().set(name, foxTex);

		function onImageLoaded(image:Image) {
			if(image == null) {
				trace('[Foxlite > FoxTexture]: Could not create image: ${name} (Image error.)');
				FoxCache.textures().remove(name);
				return;
			}
			else if(image?.buffer == null) {
				trace('[Foxlite > FoxTexture]: Could not create texture: ${name} (Asset was found, but Buffer is non-existant.)');
				FoxCache.textures().remove(name);
				return;
			}
			
			// Make it compatible with openfl...
			#if sys
			image.format = cast 2; // BGRA32
			image.premultiplied = true;
			#end

			function task() {
				var tex = FoxRenderer.getContext().createTexture(image.width, image.height, format, false);
				tex.__uploadFromImage(image);
				image = null;
				foxTex.takeGL(tex);
			}

			if(FoxRenderer.forceSyncLoading)
				task();
			else
				FoxRenderer.runTaskAtNextDraw(task);
		}

		if(isDataUrl) {
			// We can load it right away
			var components = name.split(',');
			var image = Image.fromBase64(components[1], components[0].substr(5, components[0].indexOf(';base64')-5));
			onImageLoaded(image); 
		} 
		else {
			// If we're on the main thread, load it async, else lime's own thread pool system clashes with itself (bruh)
			if(ThreadPool.isMainThread() && !FoxRenderer.forceSyncLoading)
				Image.loadFromFile(name).onComplete(image -> onImageLoaded(image));
			else
				onImageLoaded(Image.fromFile(name));
		}

		return foxTex;
	}

	/**
		Loads a compressed texture.

		Foxlite supports S3TC formats (DXT) in all platforms.
	**/
	public static function fromImageCompressed(name:String, ?mipmaps:Bool, ?format:Int, ?params):FoxTexture {
		return null;
	}

	/**
		Creates a texture on the GPU, this texture can be used as a render target.

		For a friendly list of available formats, check MDN's [texImage2D() types](https://developer.mozilla.org/en-US/docs/Web/API/WebGLRenderingContext/texImage2D#type). 
		
		It applies for standard OpenGL aswell, with the exception of `WEBGL_`.
	**/
	public static function create(width:Int, height:Int, format:String="rgba", type:String="unsigned_byte"):FoxTexture {
		var tex = FoxTexture.wrapGL(FoxRenderer.createTextureStorage(width, height, format, type));
		tex.__format = format.toUpperCase();
		tex.__type = type.toUpperCase();
		return tex;
	}

	/**
		Lighter version of fromBitmapData()
	
		Note: Use this **if** the bitmap data **already has a GPU texture attached** to it.
	*/
	public static function wrap(bitmap:BitmapData):FoxTexture {
		var texture = new FoxTexture();
		texture.take(bitmap);
		return texture;
	}

	/*
	* For wrapping GLTextures 
	*/
	public static function wrapGL(glTexture:TextureBase):FoxTexture {
		var texture = new FoxTexture();
		texture.glTexture = glTexture;
		return texture;
	}

}