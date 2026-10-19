local screenShader = Lg.newShader("/res/shaders/screen.frag.glsl")

local uniforms = {
    master = 1,
    soft_sampling = 0.85,
    scan_on = 1,
    scan_adaptive_on = 1,
    scan_strength = 0.50,
    scan_bright_strength = 0.40,
    scan_power = 1.2,
    scan_phase = 0,
    scan_response = 1.3,
    aberration_on = 1,
    aberration_px = 0.1,
    glow_on = 1,
    glow_strength = 0.08,
    glow_radius_px = 1.0,
    glow_threshold = 0.20,
    gain_on = 1,
    gain = 1.25,
    contrast_on = 1,
    contrast = 1.00,
    saturation_on = 1,
    saturation = 1.00,
    vignette_on = 0,
    vignette_strength = 0.15,
    vignette_power = 1.5,
    noise_on = 0,
    noise_strength = 0.005,
    pixel_rounding = 0.7,
    pixel_corner_round = 0,
}

for nm, v in pairs(uniforms) do
    screenShader:send(nm, v)
end

return screenShader