shader_type canvas_item;
render_mode blend_mix, unshaded;

// 绿幕抠像：RGB 距离 + YCbCr 色度距离 + 绿色通道溢出抑制。
uniform vec4 key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
uniform float similarity : hint_range(0.0, 1.0) = 0.4;
uniform float smoothness : hint_range(0.0, 1.0) = 0.1;
uniform float spill_suppression : hint_range(0.0, 1.0) = 0.3;

vec3 rgb_to_ycbcr(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	float cb = 0.564 * (c.b - y);
	float cr = 0.713 * (c.r - y);
	return vec3(y, cb, cr);
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	float max_rb = max(tex_color.r, tex_color.b);
	float green_diff = tex_color.g - max_rb;

	vec3 key_yuv = rgb_to_ycbcr(key_color.rgb);
	vec3 tex_yuv = rgb_to_ycbcr(tex_color.rgb);
	float dist_rgb = distance(tex_color.rgb, key_color.rgb);
	float dist_yuv = distance(tex_yuv.yz, key_yuv.yz);
	float dist = max(dist_rgb, dist_yuv * 1.35);

	float feather = max(smoothness, 0.001);
	float alpha = smoothstep(similarity, similarity + feather, dist);
	if (green_diff > 0.12) {
		alpha *= 1.0 - smoothstep(0.12, 0.35, green_diff);
	}

	if (green_diff > 0.0) {
		tex_color.g = mix(tex_color.g, max_rb, spill_suppression);
	}

	COLOR = vec4(tex_color.rgb, tex_color.a * alpha);
}
