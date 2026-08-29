shader_type canvas_item;

// 视频抠像。
//
// Godot 4 只支持 Ogg Theora，而 Theora **没有 Alpha 通道**，视频会画成一块不透明矩形，
// 破坏桌宠的透明窗口效果。这里用抠像把视频背景还原成透明。
//
// 参数由 scripts/sun_pet.gd 的 @export 变量驱动（在主场景根节点的检查器里调）：
//   key_mode = 0 关闭抠像（视频原样显示，背景不透明）
//   key_mode = 1 色度键：抠掉接近 key_color 的像素（绿幕/蓝幕/纯色背景）
//   key_mode = 2 暗底透明：抠掉亮度低于阈值的像素（黑底视频）
//   key_mode = 3 亮底透明：抠掉亮度高于阈值的像素（白底视频）

uniform int key_mode : hint_range(0, 3) = 0;
uniform vec3 key_color : source_color = vec3(0.0, 1.0, 0.0);
uniform float key_threshold : hint_range(0.0, 1.0) = 0.28;
uniform float key_softness : hint_range(0.001, 1.0) = 0.12;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float alpha = 1.0;

	if (key_mode == 1) {
		// 与背景色的距离越远越不透明，softness 控制边缘羽化宽度。
		float dist = distance(src.rgb, key_color);
		alpha = smoothstep(key_threshold, key_threshold + key_softness, dist);
	} else if (key_mode == 2) {
		float luma = max(max(src.r, src.g), src.b);
		alpha = smoothstep(key_threshold, key_threshold + key_softness, luma);
	} else if (key_mode == 3) {
		float luma = min(min(src.r, src.g), src.b);
		alpha = 1.0 - smoothstep(key_threshold - key_softness, key_threshold, luma);
	}

	COLOR = vec4(src.rgb, src.a * alpha);
}
