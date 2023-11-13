#ifndef SIMPLELIT_2DARRAY_PASS_INCLUDED
#define SIMPLELIT_2DARRAY_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

struct appdata
{
    float4 positionOS : POSITION;
    float3 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 staticLightmapUV : TEXCOORD1;
    float2 dynamicLightmapUV : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 positionCS : SV_POSITION;
    float3 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;

    #ifdef _NORMALMAP
    half4 normalWS : TEXCOORD2;
    half4 tangentWS : TEXCOORD3;
    half4 bitagentWS : TEXCOORD4;
    #else
    half3 normalWS : TEXCOORD2;
    #endif

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    half4 fogFactorAndVertexLight : TEXCOORD5;
    #else
    half fogFactor : TEXCOORD5;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord : TEXCOORD6;
    #endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
    #ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD8;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};


void InitializeInputData(v2f i, half3 normalTS, out InputData inputData)
{
    inputData = (InputData)0;

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

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), i.fogFactorAndVertexLight.x);
    inputData.vertexLighting = i.fogFactorAndVertexLight.yzw;
    #else
    inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), i.fogFactor);
    inputData.vertexLighting = half3(0, 0, 0);
    #endif

    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(i.staticLightmapUV, i.dynamicLightmapUV, i.vertexSH, inputData.normalWS);
    #else
    inputData.bakedGI = SAMPLE_GI(i.staticLightmapUV, i.vertexSH, inputData.normalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(i.staticLightmapUV);
}


v2f vert(appdata v)
{
    v2f o = (v2f)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);

    #if defined(_FOG_FRAGMENT)
    half fogFactor = 0;
    #else
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    o.uv.xy = TRANSFORM_TEX(v.uv.xy, _BaseMap);
    o.uv.z = v.uv.z;
    o.positionWS.xyz = vertexInput.positionWS;
    o.positionCS = vertexInput.positionCS;

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
    v.dynamicLightmapUV = v.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(o.normalWS.xyz, o.vertexSH);

    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
    o.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
    #else
    o.fogFactor = fogFactor;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    o.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    return o;
}

half4 frag(v2f i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

    SurfaceData surfaceData;
    InitializeSurfaceData(i.uv, surfaceData);

    InputData inputData;
    InitializeInputData(i, surfaceData.normalTS, inputData);

    half4 color = UniversalFragmentBlinnPhong(inputData, surfaceData);
    color.rgb = MixFog(color.rgb, inputData.fogCoord);
    color.a = OutputAlpha(color.a, _Surface);
    return color;
}

#endif