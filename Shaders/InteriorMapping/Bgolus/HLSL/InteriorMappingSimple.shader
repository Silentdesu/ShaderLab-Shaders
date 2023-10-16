Shader "Custom/InteriorMapping - simple"
{
    Properties
    {
        _RoomTex("Room Atlas RGB (alpha is not needed)", 2D) = "gray" {}
        _RoomMaxDepth01("Room Max Depth define(0 to 1)", range(0.001,0.999)) = 0.5
        _RoomCount("Room Count(X count,Y count)", vector) = (1,1,0,0)

        _WindowFrameTex ("Window Frame Texture", 2D) = "white" {}
        
        _DirtTex ("DirtTex", 2D) = "white" {}
        _DirtAlpha ("Dirt Alpha", Range(0, 1)) = 0.01
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Interior Simple"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/InteriorMappingSimplePass.hlsl"
            
            ENDHLSL
        }
    }
}