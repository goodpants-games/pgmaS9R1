local fontres = {}

fontres.monogram = Lg.newFont("res/fonts/monogram.ttf", 16, "mono", 1.0)
fontres.quinque = Lg.newFont("res/fonts/QuinqueFive.ttf", 5, "mono", 1.0)
fontres.bold = Lg.newImageFont("res/fonts/bold.png",
    " -.,:;!?1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
fontres.chunkyNumerals = Lg.newImageFont("res/fonts/chunky_numerals.png",
    "0123456789 ")

return fontres