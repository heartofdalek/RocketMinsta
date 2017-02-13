textures/items_frame
{
    dpreflectcube cubemaps/rtzapper/reflect1  
    {
        map textures/items_frame.tga
        rgbGen lightingDiffuse
    }
} 

textures/items_heart
{
	dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/items_heart.tga
		tcgen base
        rgbGen lightingDiffuse
    }
} 

textures/items_heart_fx
{
    dpreflectcube cubemaps/rtzapper/reflect1 
	surfaceparm trans
    {
        map textures/items_heart_fx.tga
        tcMod scroll 0.3 0.4
		//tcMod scale 2 2
		//tcMod rotate -5
		tcgen base
        blendfunc add
        rgbgen lightingDiffuse
    }
} 
