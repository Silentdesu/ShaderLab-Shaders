#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Includes/InteriorUVFunction.hlsl"
#include "Includes/TangentSpaceFunction.hlsl"

struct appdata
{
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 tangentViewDir : TEXCOORD1;
    float3 positionWS : TEXCOORD2;

    #ifdef _NORMALMAP
    half4 normalWS : TEXCOORD4;
    half4 tangentWS : TEXCOORD5;
    half bitagentWS : TEXCOORD6;
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

sampler2D _RoomTex;
sampler2D _WindowFrameTex;
sampler2D _DirtTex;

CBUFFER_START(UnityPerMaterial)
    float4 _RoomTex_ST;
    float4 _WindowFrameTex_ST;
    float4 _DirtTex_ST;
    float _RoomMaxDepth01;
    float2 _RoomCount;
    half _DirtAlpha;
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

SurfaceData createSurfaceData(const v2f i)
{
    SurfaceData o = (SurfaceData)0;
    
    float2 interiorUV = ConvertOriginalRawUVToInteriorUV(frac(i.uv), i.tangentViewDir, _RoomMaxDepth01);
    interiorUV /= _RoomCount;
    interiorUV = TRANSFORM_TEX(interiorUV, _RoomTex);

    //map to differrent room if needed
    const float2 roomIndex = floor(i.uv);
    interiorUV += roomIndex / _RoomCount;

    const half4 roomTexSample = tex2D(_RoomTex, interiorUV);
    const half4 windowFrameTexSample = tex2D(_WindowFrameTex, i.uv);
    const half4 dirtTexSample = tex2D(_WindowFrameTex, i.uv);

    half4 albedo = lerp(roomTexSample, windowFrameTexSample.r, windowFrameTexSample.a);
    albedo = lerp(albedo, dirtTexSample, _DirtAlpha);

    o.albedo = albedo;
    o.alpha = albedo.a;
    o.occlusion = 1.0;
    
    return o;
}

InputData createInputData(const v2f i, const half3 normalTS)
{
    InputData o = (InputData)0;

    o.positionWS = i.positionWS;

    #ifdef _NORMALMAP
    half3 viewDirWS = half3(i.normalWS.w, i.tangentWS.w, i.bitagentWS.w);
    o.tangentToWorld = half3x3(i.tangentWS.xyz, i.bitagentWS.xyz, i.normalWS.xyz);
    o.normalWS = TransformTangentToWorld(normalTS, o.tangentToWorld);
    #else
    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(o.positionWS);
    o.normalWS = i.normalWS;
    #endif

    o.normalWS = NormalizeNormalPerPixel(o.normalWS);
    viewDirWS = SafeNormalize(viewDirWS);

    o.viewDirectionWS = viewDirWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    o.shadowCoord = i.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
    #else
    o.shadowCoord = float4(0, 0, 0, 0);
    #endif

    o.fogCoord = InitializeInputDataFog(float4(o.positionWS, 1.0), i.fogFactor);
    o.vertexLighting = half3(0, 0, 0);

    #if defined(DYNAMICLIGHTMAP_ON)
    o.bakedGI = SAMPLE_GI(i.staticLightmapUV, i.dynamicLightmapUV, i.vertexSH, o.normalWS);
    #else
    o.bakedGI = SAMPLE_GI(i.staticLightmapUV, i.vertexSH, o.normalWS);
    #endif

    o.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);
    o.shadowMask = SAMPLE_SHADOWMASK(i.staticLightmapUV);
    
    return o;
}

v2f vert(appdata v)
{
    v2f o;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);

    const VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS);
    const VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);

    #if defined(_FOG_FRAGMENT)
    half fogFactor = 0;
    #else
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif
    
    o.uv = v.uv * _RoomCount;
    o.positionWS = vertexInput.positionWS;
    o.positionCS = vertexInput.positionCS;

    //find view dir Object Space
    const float3 camPosObjectSpace = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)).xyz;
    const float3 viewDirObjectSpace = v.positionOS.xyz - camPosObjectSpace;

    //get tangent space view vector
    o.tangentViewDir = DirOSToTS(viewDirObjectSpace, v.normalOS, v.tangentOS);

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

    half4 outputColor = UniversalFragmentBlinnPhong(inputData, surfaceData);
    outputColor.rgb = MixFog(outputColor.rgb, inputData.fogCoord);
    
    return outputColor;
}
