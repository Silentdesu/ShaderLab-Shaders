﻿//copied & refactor, source = https://forum.unity.com/threads/interior-mapping.424676/#post-2751518
Shader "Custom/InteriorMapping - 2D Atlas"
{
    Properties
    {
        [MainColor] _BaseColor ("Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Room Atlas RGB (A - back wall depth01)", 2D) = "gray" {}
        _Rooms("Room Atlas Rows&Cols (XY)", Vector) = (1,1,0,0)

        [Toggle(_WINDOWFRAMEMAP)] _EnableWindowFrameMap ("Enable Window Frame Map", Float) = 0
        _WindowFrameMap ("Window Frame Map", 2D) = "white" {}
        [Toggle(_NORMALMAP)] _EnableNormalMap ("Enable Normal Map", Float) = 0
        [Normal] [NoScaleOffset] _WindowFrameNormalMap ("Window Frame Normal Map", 2D) = "white" {}
        [Toggle(_DIRTMAP)] _EnableDirtMap ("Enable Dirt Map", Float) = 0
        _DirtMap ("Dirt Map", 2D) = "white" {}
        _DirtAlpha ("Dirt Alpha", Range(0, 1)) = 0.01

        [Toggle(_EMISSION)] _UseEmission ("Enable Emission", Float) = 0
        [HDR] _EmissionColor ("Emission Color", Color) = (1, 1, 1, 1)
        _EmissionMultiplier ("Emission Multiplier", Range(0, 1)) = 0
        
        [HiddenInInspector] _Cutoff ("Alpha Clipping", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Name "InteriorAtlas"
            Tags
            {
                "LightMode" = "UniversalForward"
            }
            ZWrite On
            ZTest LEqual
            
            HLSLPROGRAM
            #pragma exclude_renderers gles opengl
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _WINDOWFRAMEMAP
            #pragma shader_feature_local _DIRTMAP
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

            #include "Includes/InteriorMappingAtlasInput.hlsl"
            #include "Includes/InteriorMappingAtlasPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster"
            }

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma exclude_renderers gles opengl
            #pragma target 4.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _GLOSSINESS_FROM_BASE_ALPHA

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Includes/InteriorMappingAtlasInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "DepthOnly"
            Tags
            {
                "LightMode" = "DepthOnly"
            }
        
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back
        
            HLSLPROGRAM
            #pragma exclude_renderers gles opengl
            #pragma target 4.0
        
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
        
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _GLOSSINESS_FROM_BASE_ALPHA
        
            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Includes/InteriorMappingAtlasInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
    Fallback Off
}