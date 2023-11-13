#ifndef INTERIOR_MAPPING_ATLAS_INPUT_INCLUDED
#define INTERIOR_MAPPING_ATLAS_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

#include "InteriorUVFunction.hlsl"
#include "RandomFunction.hlsl"

TEXTURE2D(_WindowFrameMap); SAMPLER(sampler_WindowFrameMap);
TEXTURE2D(_WindowFrameNormalMap); SAMPLER(sampler_WindowFrameNormalMap);
TEXTURE2D(_DirtMap); SAMPLER(sampler_DirtMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _WindowFrameMap_ST;
    float4 _WindowFrameNormalMap_ST;
    float4 _DirtMap_ST;
    half4 _BaseColor;
    half4 _EmissionColor;
    half2 _Rooms;
    half _DirtAlpha;
    half _EnableEmission;
    half _EmissionMultiplier;
    half _EnableWindowFrameMap;
    half _EnableNormalMap;
    half _Cutoff;
CBUFFER_END

#ifdef UNITY_DOTS_INSTANCING_ENABLED
    UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
        UNITY_DOTS_INSTANCE_PROP(float4, _BaseColor)
        UNITY_DOTS_INSTANCE_PROP(float4, _EmissionColor)
        UNITY_DOTS_INSTANCE_PROP(float2, _Rooms)
        UNITY_DOTS_INSTANCE_PROP(float,  _DirtAlpha)
        UNITY_DOTS_INSTANCE_PROP(float,  _EnableEmission)
        UNITY_DOTS_INSTANCE_PROP(float,  _EmissionMultiplier)
        UNITY_DOTS_INSTANCE_PROP(float,  _EnableNormalMap)
        UNITY_DOTS_INSTANCE_PROP(float,  _EnableWindowFrameMap)
        UNITY_DOTS_INSTANCE_PROP(float,  _Cutoff)
    UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

    #define _BaseColor              UNITY_ACESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4,  Metadata_BaseColor)
    #define _EmissionColor          UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float4, Metadata_EmissionColor)
    #define _Rooms                  UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float2, Metadata_Rooms)
    #define _DirtAlpha              UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_DirtAlpha)
    #define _EnableEmission         UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_EnableEmission)
    #define _EmissionMultiplier     UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_EmissionMultiplier)
    #define _EnableNormalMap        UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_EnableNormalMap)
    #define _EnableWindowFrameMap   UNITY_ACCESS_DOTS_INSTANCED_PROP_FROM_MACRO(float,  Metadata_EnableWindowFrameMap)
#endif

inline SurfaceData createSurfaceData(const float2 uv, const float2 windowFrameUV, const float3 tangentViewDir)
{
    SurfaceData surfaceData = (SurfaceData)0;

    // room uvs
    const float2 roomUV = frac(uv);
    float2 roomIndexUV = floor(uv);

    // randomize the room
    float2 n = floor(rand2(roomIndexUV.x + roomIndexUV.y * (roomIndexUV.x + 1)) * _Rooms.xy);
    roomIndexUV += n; //colin: result = index XY + random (0,0)~(3,1)

    // get room depth from room atlas alpha
    const half roomMaxDepth01 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, (roomIndexUV + 0.5) / _Rooms).a;
    // sample room atlas texture
    const float2 interiorUV = ConvertOriginalRawUVToInteriorUV(roomUV, tangentViewDir, roomMaxDepth01);

    #if _EMISSION
    const half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, (roomIndexUV + interiorUV) / _Rooms) *
        _EmissionColor * _EmissionMultiplier;
    #else
    const half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, (roomIndexUV + interiorUV) / _Rooms);
    #endif

    #if _WINDOWFRAMEMAP
    const half4 windowFrameSample = SAMPLE_TEXTURE2D(_WindowFrameMap, sampler_WindowFrameMap, windowFrameUV);
    half4 outputColor = lerp(albedo, windowFrameSample, windowFrameSample.a);
    #else
    half4 outputColor = albedo;
    #endif

    #if _DIRTMAP
    const half4 dirtTexSample = SAMPLE_TEXTURE2D(_DirtMap, sampler_DirtMap, uv);
    outputColor = lerp(outputColor, dirtTexSample, _DirtAlpha);
    #endif
    surfaceData.alpha = outputColor.a;
    surfaceData.albedo = outputColor.rgb;

    surfaceData.normalTS = SampleNormal(windowFrameUV, TEXTURE2D_ARGS(_WindowFrameNormalMap, sampler_WindowFrameNormalMap));
    surfaceData.occlusion = 1.0;
    return surfaceData;
}
#endif