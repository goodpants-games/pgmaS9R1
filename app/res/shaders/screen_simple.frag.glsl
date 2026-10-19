// simpler CRT shader
uniform vec2 signal_size;

#define PI 3.1415926535898

float lerp(float a, float b, float t)
{
    return (b - a) * t + a;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    float wave = (cos((texture_coords.y * signal_size.y) * (PI*2.0)) + 1.0) / 2.0;
    // float bar = 1.0 - (max(0.0, wave - 0.75) * 4.0);
    float bar = 1.0 - wave;
    vec4 tex_smp = Texel(tex, texture_coords);
    vec3 base_color = (tex_smp.rgb * 1.5) * lerp(0.5, 1.0, bar);
    return vec4(base_color, tex_smp.a) * color;
}