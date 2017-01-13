
models/player/ayumi/null
{
    {
        map gfx/colors/black.tga
        blendfunc add
    }
}

models/player/ayumi/hair_black
{
	cull disable
	{
		map models/player/ayumi/hair.tga
		rgbGen lightingDiffuse
		alphaFunc GE128
	}
}

models/player/ayumi/hair_red
{
	cull disable
	{
		map models/player/ayumi/hair_red.tga
		rgbGen lightingDiffuse
		alphaFunc GE128
	}
}

models/player/ayumi/hair_blue
{
	cull disable
	{
		map models/player/ayumi/hair_blue.tga
		rgbGen lightingDiffuse
		alphaFunc GE128
	}
}

models/player/ayumi/shirt_red
{
	cull disable
	{
		map models/player/ayumi/shirt_red.tga
		rgbGen lightingDiffuse
	//	alphaFunc GE128
	}
}

models/player/ayumi/shirt_blue
{
	cull disable
	{
		map models/player/ayumi/shirt_blue.tga
		rgbGen lightingDiffuse
	}
}

models/player/ayumi/shirt_bright
{
    cull disable
    {
        map models/player/ayumi/shirt_bright.tga
        rgbGen lightingDiffuse
    }
}

models/player/ayumi/skirt_red
{
	cull disable
	{
		map models/player/ayumi/skirt_red.tga
		rgbGen lightingDiffuse
	}
}

models/player/ayumi/skirt_red_short
{
    cull disable
    {
        map models/player/ayumi/skirt_red.tga
        rgbGen lightingDiffuse
        alphaFunc GE128
    }
}

models/player/ayumi/skirt_blue
{
	cull disable
	{
		map models/player/ayumi/skirt_blue.tga
		rgbGen lightingDiffuse
	}
}

models/player/ayumi/skirt_blue_short
{
    cull disable
    {
        map models/player/ayumi/skirt_blue.tga
        rgbGen lightingDiffuse
        alphaFunc GE128
    }
}

models/player/ayumi/skirt
{
    cull disable
    {
        map models/player/ayumi/skirt.tga
        rgbGen lightingDiffuse
        alphaFunc GE128
    }
}

models/player/ayumi/glow
{
    cull disable
    {
        map models/player/ayumi/glow.tga
        tcMod rotate 30
        tcMod scale 0.3 0.3
        tcMod scroll 0.2 0.003
        tcGen environment
        blendfunc add
        rgbgen identity
    }
}

models/player/ayumi/jettest
{
	cull disable
	{
		clampmap models/player/ayumi/jet/jet1.tga
		blendfunc add
		rgbGen wave inversesawtooth 0 1 0 2 
		tcMod stretch inversesawtooth 1 1 0 2 
	}
	{
		clampmap models/player/ayumi/jet/jet1.tga
		blendfunc add
		rgbGen wave inversesawtooth 0.5 1 0 3 
		tcMod stretch inversesawtooth 1 0.7 0 3 
	}
	{
		clampmap models/player/ayumi/jet/jet1.tga
		blendfunc add
		rgbGen wave inversesawtooth 0 1 0 1 
		tcMod stretch inversesawtooth 1 1 0 1 
	}
	{
		clampmap models/player/ayumi/jet/jet2.tga
		blendfunc add
		rgbGen wave inversesawtooth 0.5 1 0 5 
		tcMod stretch sawtooth 1.9 0.8 0 5 
	}
	{
		clampmap models/player/ayumi/jet/jet2.tga
		blendfunc add
		rgbGen wave inversesawtooth 0.5 1 0 2 
		tcMod stretch sawtooth 0.5 1.2 0 2 
	}
}

models/player/ayumi/jet2
{
	cull disable
	{
		animmap 30 models/player/ayumi/jet/jet3a.tga models/player/ayumi/jet/jet3b.tga models/player/ayumi/jet/jet3c.tga models/player/ayumi/jet/jet3d.tga models/player/ayumi/jet/jet3e.tga models/player/ayumi/jet/jet3f.tga models/player/ayumi/jet/jet3g.tga models/player/ayumi/jet/jet3h.tga 
		blendfunc add
		rgbGen wave inversesawtooth 0 1 0 30 
	}
	{
		animmap 30 models/player/ayumi/jet/jet3b.tga models/player/ayumi/jet/jet3c.tga models/player/ayumi/jet/jet3d.tga models/player/ayumi/jet/jet3e.tga models/player/ayumi/jet/jet3f.tga models/player/ayumi/jet/jet3g.tga models/player/ayumi/jet/jet3h.tga models/player/ayumi/jet/jet3a.tga 
		blendfunc add
		rgbGen wave sawtooth 0 1 0 30 
	}
	{
		animmap 15 models/player/ayumi/jet/jet3h.tga models/player/ayumi/jet/jet3g.tga models/player/ayumi/jet/jet3f.tga models/player/ayumi/jet/jet3e.tga models/player/ayumi/jet/jet3d.tga models/player/ayumi/jet/jet3c.tga models/player/ayumi/jet/jet3b.tga models/player/ayumi/jet/jet3a.tga 
		blendfunc add
		rgbGen wave inversesawtooth 0 1 0 15 
	}
	{
		animmap 15 models/player/ayumi/jet/jet3g.tga models/player/ayumi/jet/jet3f.tga models/player/ayumi/jet/jet3e.tga models/player/ayumi/jet/jet3d.tga models/player/ayumi/jet/jet3c.tga models/player/ayumi/jet/jet3b.tga models/player/ayumi/jet/jet3a.tga models/player/ayumi/jet/jet3h.tga 
		blendfunc add
		rgbGen wave sawtooth 0 1 0 15 
	}
	{
		animmap 15 models/player/ayumi/jet/jet3smk1.tga models/player/ayumi/jet/jet3smk2.tga models/player/ayumi/jet/jet3smk3.tga models/player/ayumi/jet/jet3smk4.tga models/player/ayumi/jet/jet3smk5.tga models/player/ayumi/jet/jet3smk6.tga models/player/ayumi/jet/jet3smk7.tga 
		blendfunc add
		rgbGen const ( 0.337255 0.184314 0.466667 )
		tcMod rotate 153
	}
	{
		animmap 15 models/player/ayumi/jet/jet3smk7.tga models/player/ayumi/jet/jet3smk1.tga models/player/ayumi/jet/jet3smk2.tga models/player/ayumi/jet/jet3smk3.tga models/player/ayumi/jet/jet3smk4.tga models/player/ayumi/jet/jet3smk5.tga models/player/ayumi/jet/jet3smk6.tga 
		blendfunc add
		rgbGen const ( 0.294118 0.235294 0.482353 )
		tcMod rotate -95
	}
}

