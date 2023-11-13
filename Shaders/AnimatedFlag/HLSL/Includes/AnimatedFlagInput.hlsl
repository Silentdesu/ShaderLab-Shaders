#ifndef ANIMATED_FLAG_INPUT_INCLUDED
#define ANIMATED_FLAG_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

// TEXTURE2D(_BaseMap);
// SAMPLER(sampler_BaseMap);
TEXTURE2D(_DisplacementMap);
SAMPLER(sampler_DisplacementMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _DisplacementMap_ST;
    half4 _BaseColor;
    half _AnimationSpeedMultiplier;
    half _DisplacementMapMultiplier;
    half _NoiseStrength;
    half _OffsetStrengthY;
    half _Cutoff;
CBUFFER_END


#if UNITY_DOTS_INSTANCING_ENABLED
UNITY_DOTS_INSTANCING_START(Props)
    UNITY_DOTS_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DOTS_INSTANCED_PROP(float,  _AnimationSpeedMultiplier)
    UNITY_DOTS_INSTANCED_PROP(float,  _DisplacementMapMultiplier)
    UNITY_DOTS_INSTANCED_PROP(float,  _NoiseStrength)
    UNITY_DOTS_INSTANCED_PROP(float,  _OffsetStrengthY)
    UNITY_DOTS_INSTANCED_PROP(float,  _Cutoff)

    #define _BaseColor                 UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4, Metadata_BaseColor)
    #define _AnimationSpeedMultiplier  UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_AnimationSpeedMultiplier)
    #define _DisplacementMapMultiplier UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_DisplacementMapMultiplier)
    #define _NoiseStrength             UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_NoiseStrength)
    #define _OffsetStrengthY           UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_OffsetStrengthY)
    #define _Cutoff                    UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_Cutoff)
UNITY_DOTS_INSTANCING_END(Props)
#endif

SurfaceData createSurfaceData(const float2 uv)
{
    SurfaceData output = (SurfaceData)0;

    const half3 baseMapSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).rgb;
    output.albedo = baseMapSample;
    output.occlusion = 1.0;

    return output;
}
#endif