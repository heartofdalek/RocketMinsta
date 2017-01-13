textures/rtzrifle
{
    // surfaceparm nomipmaps
    dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/rtzrifle.tga
        rgbGen lightingDiffuse
    }
} 
textures/rtzrifle_scope
{
    // surfaceparm nomipmaps
    dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/rtzrifle_scope.tga
        rgbGen lightingDiffuse
    }
} 
/textures/rtzrifle_scope_lens_01
{
	cull none
	surfaceparm trans
	dpreflectcube cubemaps/rtzapper/reflect1
    {
        map textures/rtzrifle_scope_lens_01.tga
		rgbGen lightingDiffuse
		blendfunc add
		tcgen environment
    }
} 
/textures/rtzrifle_scope_lens_02
{
	cull none
	surfaceparm trans
	dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/rtzrifle_scope_lens_02.tga
		rgbGen lightingDiffuse
		blendfunc add
		tcgen environment
    }
} 
/textures/rtzrifle_scope_lens_03
{
	dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/rtzrifle_scope_lens_03.tga
		tcgen environment 
    }
} 
