Shader "Custom/ScrollingBillboard"
{
    Properties
    {
        [MainColor] _BaseColor ("Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap ("Texture", 2D) = "white" {}

        _ScrollMap ("Scroll Map", 2D) = "white" {}
        [Toggle(_SCROLL_Y)] _ScrollY ("Scroll Y", Float) = 0
        _ScrollMapAlpha ("Scroll Map Alpha", Range(0, 1)) = 0.025
        _ScrollSpeedMultiplier ("Scroll Speed Multiplier", Range(0, 100)) = 1
        
        [HideInInspector] _Cutoff("Alpha Clipping", Float) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 300

        Pass
        {
            Name "ScrollingBillboard"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma exclude_renderers gles opengl
            #pragma target 4.0

            #pragma shader_feature_local _SCROLL_Y
            
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex vert
            #pragma fragment frag

            #include "Includes/ScrollingBillboardInput.hlsl"
            #include "Includes/ScrollingBillboardPass.hlsl"
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
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles opengl
            #pragma target 4.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Includes/ScrollingBillboardInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
    }
    Fallback Off
}