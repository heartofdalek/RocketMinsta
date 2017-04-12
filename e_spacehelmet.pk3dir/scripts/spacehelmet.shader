textures/spacehelmet
{
    surfaceparm nomipmaps
    dpreflectcube cubemaps/rtzapper/reflect1 
    {
        map textures/spacehelmet.tga
        rgbGen lightingDiffuse
    }
}

textures/spacehelmet_glass
{
    cull none
	surfaceparm trans
	dpreflectcube cubemaps/rtzapper/reflect1
    {
        map textures/spacehelmet_glass.tga
        blendfunc add
        rgbgen lightingDiffuse
    }
}

textures/spacehelmet_lights 
{
	surfaceparm trans
	cull none
    {
        map textures/spacehelmet_lights.tga
        //tcMod scroll -1 0.3
        blendfunc add
        rgbgen identity
    }
}