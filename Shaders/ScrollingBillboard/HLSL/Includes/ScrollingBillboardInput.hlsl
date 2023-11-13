#ifndef SCROLLING_BILLBOARD_INPUT_INCLUDED
#define SCROLLING_BILLBOARD_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl" //For DepthOnlyPass

TEXTURE2D(_ScrollMap);
SAMPLER(sampler_ScrollMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _ScrollMap_ST;
    half4 _BaseColor;
    half _ScrollY;
    half _ScrollMapAlpha;
    half _ScrollSpeedMultiplier;
    half _Cutoff;
CBUFFER_END

#ifdef UNITY_DOTS_INSTANCING_ENABLED
    UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
        UNITY_DOTS_INSTANCE_PROP(float, _ScrollY)
        UNITY_DOTS_INSTANCE_PROP(float, _ScrollMapAlpha)
        UNITY_DOTS_INSTANCE_PROP(float, _ScrollSpeedMultiplier)
    UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

    #define _ScrollY                UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_ScrollY)
    #define _ScrollMapAlpha         UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_ScrollMapAlpha)
    #define _ScrollSpeedMultiplier  UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_ScrollSpeedMultiplier)

#endif

#endif