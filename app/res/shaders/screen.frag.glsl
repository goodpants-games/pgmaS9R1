// Thanks to Chromecide for letting me steal his scratch pen plus shader!!!!

// try to use highest available precision float
#define HIGHP_OR_MEDIUMP LOVE_HIGHP_OR_MEDIUMP
#ifdef GL_ES
precision HIGHP_OR_MEDIUMP float;
#endif

uniform HIGHP_OR_MEDIUMP float u_timer;

uniform HIGHP_OR_MEDIUMP float master;
uniform HIGHP_OR_MEDIUMP float scan_on;
uniform HIGHP_OR_MEDIUMP float scan_strength;
uniform HIGHP_OR_MEDIUMP float scan_power;
uniform HIGHP_OR_MEDIUMP float scan_phase;
uniform HIGHP_OR_MEDIUMP float aberration_on;
uniform HIGHP_OR_MEDIUMP float aberration_px;
uniform HIGHP_OR_MEDIUMP float glow_on;
uniform HIGHP_OR_MEDIUMP float glow_strength;
uniform HIGHP_OR_MEDIUMP float glow_radius_px;
uniform HIGHP_OR_MEDIUMP float glow_threshold;
uniform HIGHP_OR_MEDIUMP float gain_on;
uniform HIGHP_OR_MEDIUMP float gain;
uniform HIGHP_OR_MEDIUMP float contrast_on;
uniform HIGHP_OR_MEDIUMP float contrast;
uniform HIGHP_OR_MEDIUMP float saturation_on;
uniform HIGHP_OR_MEDIUMP float saturation;
uniform HIGHP_OR_MEDIUMP float vignette_on;
uniform HIGHP_OR_MEDIUMP float vignette_strength;
uniform HIGHP_OR_MEDIUMP float vignette_power;
uniform HIGHP_OR_MEDIUMP float noise_on;
uniform HIGHP_OR_MEDIUMP float noise_strength;
uniform HIGHP_OR_MEDIUMP float scan_adaptive_on;
uniform HIGHP_OR_MEDIUMP float scan_bright_strength;
uniform HIGHP_OR_MEDIUMP float scan_response;
uniform HIGHP_OR_MEDIUMP float pixel_rounding;
uniform HIGHP_OR_MEDIUMP float pixel_corner_round;
uniform HIGHP_OR_MEDIUMP float soft_sampling;
uniform HIGHP_OR_MEDIUMP vec2 signal_size;

//Fragment Shader
mediump vec4 effect(mediump vec4 color, Image tex, mediump vec2 texture_coords, mediump vec2 screen_coords) {
    float offset_uv = float(1);
    float texel_x = float(1);
    float texel_y = float(1);
    float luma = float(1);
    float highlight = float(1);
    float phase_y = float(1);
    float edge_y = float(1);
    float scan_factor = float(1);
    float center_x = float(1);
    float center_y = float(1);
    float vignette_factor = float(1);
    float noise_value = float(1);
    float noise_amount = float(1);
    float beam_curve = float(1);
    float beam_luma = float(1);
    float adaptive_amount = float(1);
    float adaptive_strength = float(1);
    float cell_x = float(1);
    float cell_y = float(1);
    float curved_x = float(1);
    float curved_y = float(1);
    float blend_x = float(1);
    float blend_y = float(1);
    float round_x = float(1);
    float top_difference = float(1);
    float bottom_difference = float(1);
    float edge_contrast = float(1);
    float corner_factor = float(1);
    vec2 uv = vec2(1);
    vec2 source_pos = vec2(1);
    vec2 base_pos = vec2(1);
    vec2 cell_pos = vec2(1);
    vec2 uv_00 = vec2(1);
    vec2 uv_10 = vec2(1);
    vec2 uv_01 = vec2(1);
    vec2 uv_11 = vec2(1);
    vec2 nearest_uv = vec2(1);
    vec4 center_sample = vec4(1);
    vec4 work_color = vec4(1);
    vec4 red_sample = vec4(1);
    vec4 blue_sample = vec4(1);
    vec4 glow_color = vec4(1);
    vec4 gray_color = vec4(1);
    vec4 sample_00 = vec4(1);
    vec4 sample_10 = vec4(1);
    vec4 sample_01 = vec4(1);
    vec4 sample_11 = vec4(1);
    vec4 row_top = vec4(1);
    vec4 row_bottom = vec4(1);
    vec4 rounded_sample = vec4(1);
    vec4 nearest_sample = vec4(1);


uv = vec2(texture_coords);

center_sample = vec4(Texel(tex,uv));

if ((master < float(0.5))) {
  return center_sample;
}
else{
  source_pos = vec2(((uv * signal_size) - vec2(float(0.5),float(0.5))));

  base_pos = vec2(floor(source_pos));

  cell_pos = vec2(fract(source_pos));

  cell_x = float(cell_pos.x);

  cell_y = float(cell_pos.y);

  curved_x = float((cell_x * (cell_x * (float(3) - (float(2) * cell_x)))));

  curved_y = float((cell_y * (cell_y * (float(3) - (float(2) * cell_y)))));

  blend_x = float((cell_x + ((curved_x - cell_x) * pixel_rounding)));

  blend_y = float((cell_y + ((curved_y - cell_y) * pixel_rounding)));

  uv_00 = vec2(((base_pos + vec2(float(0.5),float(0.5))) / signal_size));

  uv_10 = vec2(((base_pos + vec2(float(1.5),float(0.5))) / signal_size));

  uv_01 = vec2(((base_pos + vec2(float(0.5),float(1.5))) / signal_size));

  uv_11 = vec2(((base_pos + vec2(float(1.5),float(1.5))) / signal_size));

  sample_00 = vec4(Texel(tex,uv_00));

  sample_10 = vec4(Texel(tex,uv_10));

  sample_01 = vec4(Texel(tex,uv_01));

  sample_11 = vec4(Texel(tex,uv_11));

  row_top = vec4((sample_00 + ((sample_10 - sample_00) * blend_x)));

  row_bottom = vec4((sample_01 + ((sample_11 - sample_01) * blend_x)));

  rounded_sample = vec4((row_top + ((row_bottom - row_top) * blend_y)));

  nearest_uv = vec2(((floor((uv * signal_size)) + vec2(float(0.5),float(0.5))) / signal_size));

  nearest_sample = vec4(Texel(tex,nearest_uv));

  center_sample = vec4((nearest_sample + ((rounded_sample - nearest_sample) * soft_sampling)));

  work_color = vec4(center_sample);

  if ((aberration_on > float(0.5))) {
    offset_uv = float((aberration_px / signal_size.x));

    red_sample = vec4(Texel(tex,(uv - vec2(offset_uv,float(0)))));

    blue_sample = vec4(Texel(tex,(uv + vec2(offset_uv,float(0)))));

    work_color = vec4(vec4(red_sample.x,center_sample.y,blue_sample.z,center_sample.w));

  }
  if ((saturation_on > float(0.5))) {
    luma = float(((float(0.2126) * work_color.x) + ((float(0.7152) * work_color.y) + (float(0.0722) * work_color.z))));

    gray_color = vec4(vec4(luma,luma,luma,work_color.w));

    work_color = vec4((gray_color + ((work_color - gray_color) * vec4(saturation,saturation,saturation,float(1)))));

  }
  if ((contrast_on > float(0.5))) {
    work_color = vec4((((work_color - vec4(float(0.5),float(0.5),float(0.5),float(0))) * vec4(contrast,contrast,contrast,float(1))) + vec4(float(0.5),float(0.5),float(0.5),float(0))));

  }
  if ((gain_on > float(0.5))) {
    work_color *= vec4(gain,gain,gain,float(1));

  }
  if ((scan_on > float(0.5))) {
    phase_y = float(fract(((uv.y * signal_size.y) + scan_phase)));

    edge_y = float(abs(((phase_y * float(2)) - float(1))));

    luma = float(((float(0.2126) * work_color.x) + ((float(0.7152) * work_color.y) + (float(0.0722) * work_color.z))));

    beam_luma = float(clamp((luma * scan_response),float(0),float(1)));

    beam_luma = float(pow(beam_luma, float(2)));

    adaptive_amount = float((beam_luma * scan_adaptive_on));

    adaptive_strength = float((scan_strength + ((scan_bright_strength - scan_strength) * adaptive_amount)));

    beam_curve = float(pow(edge_y, scan_power));

    scan_factor = float((float(1) - (adaptive_strength * beam_curve)));

    round_x = float(abs(((fract((uv.x * signal_size.x)) * float(2)) - float(1))));

    top_difference = float((abs((sample_00.x - sample_10.x)) + (abs((sample_00.y - sample_10.y)) + abs((sample_00.z - sample_10.z)))));

    bottom_difference = float((abs((sample_01.x - sample_11.x)) + (abs((sample_01.y - sample_11.y)) + abs((sample_01.z - sample_11.z)))));

    edge_contrast = float(clamp(((top_difference + bottom_difference) * float(1.5)),float(0),float(1)));

    corner_factor = float((float(1) - (pixel_corner_round * (edge_contrast * (pow(round_x, float(2)) * pow(edge_y, float(2)))))));

    scan_factor = float((scan_factor * corner_factor));

    work_color *= vec4(scan_factor,scan_factor,scan_factor,float(1));

  }
  if ((glow_on > float(0.5))) {
    texel_x = float((glow_radius_px / signal_size.x));

    texel_y = float((glow_radius_px / signal_size.y));

    glow_color = vec4(vec4(float(0),float(0),float(0),float(0)));

    glow_color += Texel(tex,(uv - vec2(texel_x,float(0))));

    glow_color += Texel(tex,(uv + vec2(texel_x,float(0))));

    glow_color += Texel(tex,(uv - vec2(float(0),texel_y)));

    glow_color += Texel(tex,(uv + vec2(float(0),texel_y)));

    glow_color = vec4((glow_color / float(4)));

    luma = float(((float(0.2126) * glow_color.x) + ((float(0.7152) * glow_color.y) + (float(0.0722) * glow_color.z))));

    highlight = float(clamp(((luma - glow_threshold) / (float(1) - glow_threshold)),float(0),float(1)));

    work_color += (glow_color * vec4((highlight * glow_strength),(highlight * glow_strength),(highlight * glow_strength),float(0)));

  }
  if ((vignette_on > float(0.5))) {
    center_x = float(abs(((uv.x * float(2)) - float(1))));

    center_y = float(abs(((uv.y * float(2)) - float(1))));

    vignette_factor = float((float(1) - (vignette_strength * clamp(((pow(center_x, vignette_power) + pow(center_y, vignette_power)) * float(0.5)),float(0),float(1)))));

    work_color *= vec4(vignette_factor,vignette_factor,vignette_factor,float(1));

  }
  if ((noise_on > float(0.5))) {
    luma = float(((float(0.2126) * work_color.x) + ((float(0.7152) * work_color.y) + (float(0.0722) * work_color.z))));
    noise_value = float(fract((sin(((screen_coords.x * float(12.9898)) + ((screen_coords.y * float(78.233)) + (u_timer * float(37.719))))) * float(43758.5453))));
    noise_value = float(((noise_value - float(0.5)) * float(2)));
    noise_amount = float((noise_strength * (noise_value * clamp((luma * float(4)),float(0),float(1)))));
    work_color += vec4(noise_amount,noise_amount,noise_amount,float(0));
  }
  work_color = vec4(vec4(clamp(work_color.x,float(0),float(1)),clamp(work_color.y,float(0),float(1)),clamp(work_color.z,float(0),float(1)),float(1)));

  return work_color;
}
}