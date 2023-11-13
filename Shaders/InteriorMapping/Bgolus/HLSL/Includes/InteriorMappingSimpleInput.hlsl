#ifndef INTERIOR_MAPPING_SIMPLE_INPUT_INCLUDED
#define INTERIOR_MAPPING_SIMPLE_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "InteriorUVFunction.hlsl"

TEXTURE2D(_WindowFrameMap); SAMPLER(sampler_WindowFrameMap);
TEXTURE2D(_DirtMap); SAMPLER(sampler_DirtMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _WindowFrameMap_ST;
    float4 _DirtMap_ST;
    half4 _BaseColor;
    int2 _RoomCount;
    float _RoomMaxDepth01;
    half _DirtAlpha;
    half _Cutoff;
CBUFFER_END

#ifdef UNITY_DOTS_INSTANCING_ENABLED
    UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
        UNITY_DOTS_INSTANCE_PROP(float2, _RoomCount)
        UNITY_DOTS_INSTANCE_PROP(float, _DirtAlpha)
        UNITY_DOTS_INSTANCE_PROP(float, _RoomMaxDepth01)
    UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

    #define _RoomCount UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float2 , Metadata_RoomCount)
    #define _DirtAlpha UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_DirtAlpha)
    #define _RoomMaxDepth01 UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_RoomMaxDepth01)
#endif

SurfaceData createSurfaceData(const float2 uv, const float3 tangentViewDir)
{
    SurfaceData o = (SurfaceData)0;

    float2 interiorUV = ConvertOriginalRawUVToInteriorUV(frac(uv), tangentViewDir, _RoomMaxDepth01);
    interiorUV /= _RoomCount;
    interiorUV = TRANSFORM_TEX(interiorUV, _BaseMap);

    //map to different room if needed
    const float2 roomIndex = floor(uv);
    interiorUV += roomIndex / _RoomCount;

    const half4 roomMapSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, interiorUV);

    half4 albedo = roomMapSample;
    #if _WINDOWFRAMEMAP
    const half4 windowFrameMapSample = SAMPLE_TEXTURE2D(_WindowFrameMap, sampler_WindowFrameMap, uv);
    albedo = lerp(roomMapSample, windowFrameMapSample.r, windowFrameMapSample.a);
    #endif
    #if _DIRTMAP
    const half4 dirtMapSample = SAMPLE_TEXTURE2D(_DirtMap, sampler_DirtMap, uv);
    albedo = lerp(albedo, dirtMapSample, _DirtAlpha);
    #endif
    
    o.albedo = albedo.rgb;
    o.alpha = albedo.a;
    o.occlusion = 1.0;

    return o;
}
#endif