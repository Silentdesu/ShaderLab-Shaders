#ifndef INTERIOR_MAPPING_ATLAS_PASS_INCLUDED
#define INTERIOR_MAPPING_ATLAS_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "TangentSpaceFunction.hlsl"

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

    const SurfaceData surfaceData = createSurfaceData(i.uv, i.windowFrameUV, i.tangentViewDir);
    const InputData inputData = createInputData(i, surfaceData.normalTS);

    half4 o = UniversalFragmentBlinnPhong(inputData, surfaceData);
    o.rgb = MixFog(o.rgb, inputData.fogCoord);

    return o;
}
#endif