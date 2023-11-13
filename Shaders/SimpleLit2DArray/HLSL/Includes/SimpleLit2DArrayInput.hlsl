#ifndef SIMPLELIT_2DARRAY_INPUT_INCLUDED
#define SIMPLELIT_2DARRAY_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "../../../Library/SampleMaps.hlsl" // For DepthOnlyPass
#include "../../../Library/SampleMaps2DArray.hlsl"
#include "HLSLSupport.cginc"

UNITY_DECLARE_TEX2DARRAY(_BaseMap);
UNITY_DECLARE_TEX2DARRAY(_BumpMap);
UNITY_DECLARE_TEX2DARRAY(_SpecGlossMap);
UNITY_DECLARE_TEX2DARRAY(_EmissionMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    half4 _BaseColor;
    half4 _SpecColor;
    half3 _EmissionColor;
    half _SpecularStrength;
    half _Smoothness;
    half _NormalStrength;
    half _Surface;
    half _Cutoff;
CBUFFER_END

#ifdef UNITY_DOTS_INSTANCING_ENABLED
    UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
        UNITY_DOTS_INSTANCE_PROP(float4, _BaseColor)
        UNITY_DOTS_INSTANCE_PROP(float4, _SpecColor)
        UNITY_DOTS_INSTANCE_PROP(float4, _EmissionColor)
        UNITY_DOTS_INSTANCE_PROP(float4, _Cutoff)
        UNITY_DOTS_INSTANCE_PROP(float4, _Surface)
    UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

    #define _BaseColor      UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_BaseColor)
    #define _SpecColor      UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_SpecColor)
    #define _EmissionColor  UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_EmissionColor)
    #define _Cutoff         UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_Cutoff)
    #define _Surface        UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_Surface)
#endif

void InitializeSurfaceData(float3 uv, out SurfaceData outSurfaceData)
{
    outSurfaceData = (SurfaceData)0;

    half4 albedoAlpha = UNITY_SAMPLE_TEX2DARRAY(_BaseMap, uv);
    outSurfaceData.alpha = albedoAlpha.a * _BaseColor.a;
    AlphaDiscard(outSurfaceData.alpha, _Cutoff);

    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
    #ifdef _ALPHAPREMULTIPLY_ON
    outSurfaceData.albedo *= outSurfaceData.alpha;
    #endif

    half4 specularSmoothness = SampleSpecularSmoothness(uv, outSurfaceData.alpha, _SpecColor,
                                                        TEXTURE2D_ARRAY_ARGS(_SpecGlossMap, sampler_SpecGlossMap));
    outSurfaceData.metallic = 0.0; // unused
    outSurfaceData.specular = specularSmoothness.rgb;
    outSurfaceData.smoothness = specularSmoothness.a;
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARRAY_ARGS(_BumpMap, sampler_BumpMap));
    outSurfaceData.occlusion = 1.0;
    outSurfaceData.emission = SampleEmission(uv, _EmissionColor, TEXTURE2D_ARRAY_ARGS(_EmissionMap, sampler_EmissionMap));
}

#endif