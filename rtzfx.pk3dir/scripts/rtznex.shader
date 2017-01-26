textures/rtznex
{
    // surfaceparm nomipmaps
	cull none
    dpreflectcube cubemaps/rtzrifle/reflect1
    {
        map textures/rtznex.tga
        rgbGen lightingDiffuse
    }
} 

textures/rtznex_screen
{
    {
        animmap 0.45 textures/rtznex_screen/00_Honoka_Cheer1.tga textures/rtznex_screen/01_Honoka_Summer.tga textures/rtznex_screen/02_Honoka_Winter.tga textures/rtznex_screen/03_Eli_Cheer1.tga textures/rtznex_screen/04_Eli_Summer.tga textures/rtznex_screen/05_Eli_Winter.tga textures/rtznex_screen/06_Kotori_Cheer1.tga textures/rtznex_screen/07_Kotori_Summer.tga textures/rtznex_screen/08_Kotori_Winter.tga textures/rtznex_screen/09_Umi_Cheer1.tga textures/rtznex_screen/10_Umi_Summer.tga textures/rtznex_screen/11_Umi_Winter.tga textures/rtznex_screen/12_Rin_Cheer1.tga textures/rtznex_screen/13_Rin_Summer.tga textures/rtznex_screen/14_Rin_Winter.tga textures/rtznex_screen/15_Maki_Cheer1.tga textures/rtznex_screen/16_Maki_Summer.tga textures/rtznex_screen/17_Maki_Winter.tga textures/rtznex_screen/18_Nozomi_Cheer1.tga textures/rtznex_screen/19_Nozomi_Summer.tga textures/rtznex_screen/20_Nozomi_Winter.tga textures/rtznex_screen/21_Hanayo_Cheer1.tga textures/rtznex_screen/22_Hanayo_Summer.tga textures/rtznex_screen/23_Hanayo_Winter.tga textures/rtznex_screen/24_Nico_Cheer1.tga textures/rtznex_screen/25_Nico_Summer.tga textures/rtznex_screen/26_Nico_Winter.tga textures/rtznex_screen/27_Chika_Cheer.tga textures/rtznex_screen/28_Chika_Summer.tga textures/rtznex_screen/29_Chika_Winter.tga textures/rtznex_screen/30_Riko_Cheer.tga textures/rtznex_screen/31_Riko_Summer.tga textures/rtznex_screen/32_Riko_Winter.tga textures/rtznex_screen/33_Kanan_Cheer.tga textures/rtznex_screen/34_Kanan_Summer.tga textures/rtznex_screen/35_Kanan_Winter.tga textures/rtznex_screen/36_Dia_Cheer.tga textures/rtznex_screen/37_Dia_Summer.tga textures/rtznex_screen/38_Dia_Winter.tga textures/rtznex_screen/39_You_Cheer.tga textures/rtznex_screen/40_You_Summer.tga textures/rtznex_screen/41_You_Winter.tga textures/rtznex_screen/42_Yoshiko_Cheer.tga textures/rtznex_screen/43_Yoshiko_Summer.tga textures/rtznex_screen/44_Yoshiko_Winter.tga textures/rtznex_screen/45_Hanamaru_Cheer.tga textures/rtznex_screen/46_Hanamaru_Summer.tga textures/rtznex_screen/47_Hanamaru_Winter.tga textures/rtznex_screen/48_Mari_Cheer.tga textures/rtznex_screen/49_Mari_Summer.tga textures/rtznex_screen/50_Mari_Winter.tga textures/rtznex_screen/51_Ruby_Cheer.tga textures/rtznex_screen/52_Ruby_Summer.tga textures/rtznex_screen/53_Ruby_Winter.tga textures/rtznex_screen/54_kurotech_01.tga textures/rtznex_screen/55_kurotech_02.tga
		rgbgen identity
    }
}

textures/rtznexglow
{
    {
        map textures/zapper_fx_txt
        tcMod scroll 1.5 0.231
        blendfunc add
        rgbgen identity
    }
}

textures/glow3
{
    cull none
    deformVertexes wave 1 sin 0.1 0.05 0 1.25
    {
        map textures/rtznex_glow3.tga
        tcMod rotate 43
        tcMod scale 2.7 3.1
        tcMod scroll 3 5
        tcGen environment
        blendfunc add
        rgbgen identity
    }
} 

textures/fx_1
{
    cull none
    deformVertexes wave 1 sin 0.01 0.04 0 23.9
    {
        map textures/fx_1.tga
        blendfunc add
        rgbgen identity
    }
} 

textures/fx_2
{
    cull none
    {
        map textures/fx_2.tga
        tcMod scroll 0 -0.3
        blendfunc add
        rgbGen identity
    }
} 

textures/fx_3
{
    cull none
    {
        map textures/fx_3.tga
        tcMod scroll 0 0.5
        blendfunc add
        rgbGen identity
    }
}

textures/charge_sphere
{
    cull none
    deformVertexes wave 1 sin 0.1 0.2 0 3
    {
        map textures/charge_sphere.tga
        //tcMod rotate 43
        //tcMod scale 2.7 3.1
        //tcMod scroll 3 5
        //tcGen environment
        blendfunc add
        rgbGen identity
    }
} 

textures/charge_core
{
    cull none
	deformVertexes wave 1 sin 0.1 0.2 0 1.25
    {
        map textures/pryaxe_balls_outer.tga
        tcMod rotate 41
        tcMod scale 2.3 3.2
        tcMod scroll 1.2 0.9
        tcGen environment
        blendfunc add
        rgbGen identity
    }
}

textures/rm_nex_scope_overlay_anim
{
    {
        map textures/rm_nex_scope_overlay.tga
        blendfunc add
        tcmod scale 0.5 0.5
        tcmod scroll -0.75 0.4
    }
}
