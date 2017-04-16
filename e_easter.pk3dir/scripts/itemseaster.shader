textures/items_frame
{
    dpreflectcube cubemaps/rtzapper/reflect1  
    {
        map textures/items_frame.tga
        rgbGen lightingDiffuse
    }
} 

textures/items_eggarmor
{
	dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/items_eggarmor.tga
		tcgen environment
        rgbGen lightingDiffuse
    }
} 

textures/items_eggarmor_fx
{
    dpreflectcube cubemaps/rtzapper/reflect1 
	surfaceparm trans
    {
        map textures/items_eggarmor_fx.tga
        tcMod scroll 0.3 0.4
		//tcMod scale 2 2
		//tcMod rotate -5
		tcgen environment
        blendfunc add
        rgbgen lightingDiffuse
    }
} 

textures/items_egghp
{
	dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/items_egghp.tga
		tcgen environment
        rgbGen lightingDiffuse
    }
} 

textures/items_egghp_fx
{
    dpreflectcube cubemaps/rtzapper/reflect1 
	surfaceparm trans
    {
        map textures/items_egghp_fx.tga
        tcMod scroll 0.3 0.4
		//tcMod scale 2 2
		//tcMod rotate -5
		tcgen environment
        blendfunc add
        rgbgen lightingDiffuse
    }
} 