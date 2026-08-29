shader_type canvas_item;
render_mode blend_mix, unshaded;

// 色度键抠像（Chroma Key）。
//
// Godot 4 的 Ogg Theora 没有 Alpha 通道，视频会画成不透明矩形。
// 把接近 key_color 的像素变成透明，白底 / 绿幕 / 黑底都能用同一套参数：
//   key_color   要抠掉的颜色（#FFFFFF / #00FF00 / #000000）
//   similarity  容差：越大，越多接近色被抠掉（默认 0.35）
//   smoothness  边缘羽化：越大越软，避免锯齿（默认 0.10）
//
// 本着色器只挂在 PetFrame（TextureRect）上，TEXTURE 来自
// VideoStreamPlayer.get_video_texture()。不要挂在 VideoStreamPlayer 本身。

uniform vec3 key_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float similarity : hint_range(0.0, 1.0) = 0.35;
uniform float smoothness : hint_range(0.0, 1.0) = 0.10;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float dist = distance(src.rgb, key_color);
	float feather = max(smoothness, 0.001);
	float alpha = smoothstep(similarity, similarity + feather, dist);
	COLOR = vec4(src.rgb, src.a * alpha);
}
