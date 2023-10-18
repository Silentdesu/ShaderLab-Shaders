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
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _WINDOWFRAMEMAP
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _CLUSTERED_RENDERING

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON
            
            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/InteriorMappingSimplePass.hlsl"
            
            ENDHLSL
        }
    }
}