#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "HLSLSupport.cginc"

#include "InteriorUVFunction.hlsl"
#include "RandomFunction.hlsl"
#include "TangentSpaceFunction.hlsl"
#include "SampleMaps.hlsl"

struct appdata
{
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 staticLightmapUV : TEXCOORD1;
    float2 dynamicLightmapUV : TEXCOORD2;

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 tangentViewDir : TEXCOORD1;
    float2 windowFrameUV : TEXCOORD2;

    float3 positionWS : TEXCOORD3;

    #ifdef _NORMALMAP
    half4 normalWS : TEXCOORD4;
    half4 tangentWS : TEXCOORD5;
    half4 bitagentWS : TEXCOORD6;
    #else
    half3 normalWS : TEXCOORD4;
    #endif

    half fogFactor : TEXCOORD7;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord : TEXCOORD8;
    #endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 9);
    #ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD10;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_WindowFrameMap); SAMPLER(sampler_WindowFrameMap);
TEXTURE2D(_WindowFrameNormalMap); SAMPLER(sampler_WindowFrameNormalMap);
TEXTURE2D(_DirtMap); SAMPLER(sampler_DirtMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _WindowFrameMap_ST;
    float4 _WindowFrameNormalMap_ST;
    float4 _DirtMap_ST;
    half2 _Rooms;
    half _DirtAlpha;
    half _UseEmission;
    half4 _EmissionColor;
    half _EmissionMultiplier;
CBUFFER_END

#ifdef UNITY_DOTS_INSTANCING_ENABLED
    UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
        UNITY_DOTS_INSTANCE_PROP(float2, _Rooms)
        UNITY_DOTS_INSTANCE_PROP(float, _DirtAlpha)
        UNITY_DOTS_INSTANCE_PROP(float, _UseEmission)
        UNITY_DOTS_INSTANCE_PROP(float4, _EmissionColor)
        UNITY_DOTS_INSTANCE_PROP(float, _EmissionMultiplier)
    UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

    #define _Rooms UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float2 , Metadata_Rooms)
    #define _DirtAlpha UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_DirtAlpha)
    #define _UseEmission UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_UseEmission)
    #define _EmissionMultiplier UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_EmissionMultiplier)
    #define _EmissionColor UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float4 , Metadata_EmissionColor)
#endif

InputData createInputData(const v2f i, const half3 normalTS)
{
    InputData inputData = (InputData)0;

    inputData.positionWS = i.positionWS;

    #ifdef _NORMALMAP
    half3 viewDirWS = half3(i.normalWS.w, i.tangentWS.w, i.bitagentWS.w);
    inputData.tangentToWorld = half3x3(i.tangentWS.xyz, i.bitagentWS.xyz, i.normalWS.xyz);
    inputData.normalWS = TransformTangentToWorld(normalTS, inputData.tangentToWorld);
    #else
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(inputData.positionWS);
    inputData.normalWS = i.normalWS;
    #endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    viewDirWS = SafeNormalize(viewDirWS);

    inputData.viewDirectionWS = viewDirWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = i.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
    inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), i.fogFactor);
    inputData.vertexLighting = half3(0, 0, 0);

    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(i.staticLightmapUV, i.dynamicLightmapUV, i.vertexSH, inputData.normalWS);
    #else
    inputData.bakedGI = SAMPLE_GI(i.staticLightmapUV, i.vertexSH, inputData.normalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(i.staticLightmapUV);

    return inputData;
}

SurfaceData createSurfaceData(const v2f i)
{
    SurfaceData surfaceData = (SurfaceData)0;

    // room uvs
    const float2 roomUV = frac(i.uv);
    float2 roomIndexUV = floor(i.uv);

    // randomize the room
    float2 n = floor(rand2(roomIndexUV.x + roomIndexUV.y * (roomIndexUV.x + 1)) * _Rooms.xy);
    roomIndexUV += n; //colin: result = index XY + random (0,0)~(3,1)

    // get room depth from room atlas alpha
    const half roomMaxDepth01 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, (roomIndexUV + 0.5) / _Rooms).a;
    // sample room atlas texture
    const float2 interiorUV = ConvertOriginalRawUVToInteriorUV(roomUV, i.tangentViewDir, roomMaxDepth01);

    #if _EMISSION
    const half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, (roomIndexUV + interiorUV) / _Rooms) *
        _EmissionColor * _EmissionMultiplier;
    #else
    const half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, (roomIndexUV + interiorUV) / _Rooms);
    #endif

    #if _WINDOWFRAMEMAP
    const half4 windowFrameSample = SAMPLE_TEXTURE2D(_WindowFrameMap, sampler_WindowFrameMap, i.windowFrameUV);
    half4 outputColor = lerp(albedo, windowFrameSample, windowFrameSample.a);
    #else
    half4 outputColor = albedo;
    #endif

    const half4 dirtTexSample = SAMPLE_TEXTURE2D(_DirtMap, sampler_DirtMap, i.uv);
    outputColor = lerp(outputColor, dirtTexSample, _DirtAlpha);
    surfaceData.alpha = outputColor.a;
    surfaceData.albedo = outputColor.rgb;

    surfaceData.normalTS = SampleNormal(i.windowFrameUV, TEXTURE2D_ARGS(_WindowFrameNormalMap, sampler_WindowFrameNormalMap));
    surfaceData.occlusion = 1.0;
    return surfaceData;
}

v2f vert(appdata v)
{
    v2f o = (v2f)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);

    const VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
    const VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);

    #if defined(_FOG_FRAGMENT)
    half fogFactor = 0;
    #else
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
    o.positionWS.xyz = vertexInput.positionWS;
    o.positionCS = vertexInput.positionCS;
    o.windowFrameUV = TRANSFORM_TEX(v.uv, _WindowFrameMap);

    const float3 camPosOS = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
    const float3 viewDirOS = v.positionOS.xyz - camPosOS;

    o.tangentViewDir = DirOSToTS(viewDirOS, v.normalOS, v.tangentOS);

    #ifdef _NORMALMAP
    half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
    o.normalWS = half4(normalInput.normalWS, viewDirWS.x);
    o.tangentWS = half4(normalInput.tangentWS, viewDirWS.y);
    o.bitagentWS = half4(normalInput.bitangentWS, viewDirWS.z);
    #else
    o.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);
    #endif

    OUTPUT_LIGHTMAP_UV(v.staticLightmapUV, unity_LightmapST, o.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
    o.dynamicLightmapUV = v.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(o.normalWS.xyz, o.vertexSH);

    o.fogFactor = fogFactor;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    o.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    return o;
}

half4 frag(v2f i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);

    const SurfaceData surfaceData = createSurfaceData(i);
    const InputData inputData = createInputData(i, surfaceData.normalTS);

    half4 o = UniversalFragmentBlinnPhong(inputData, surfaceData);
    o.rgb = MixFog(o.rgb, inputData.fogCoord);

    return o;
}
