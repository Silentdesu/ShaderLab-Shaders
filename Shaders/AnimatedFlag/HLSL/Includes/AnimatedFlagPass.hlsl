#ifndef ANIMATED_FLAG_PASS_INCLUDED
#define ANIMATED_FLAG_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

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
    float3 positionWS : TEXCOORD1;
    float3 tangentViewDirWS : TEXCOORD2;

    half3 normalWS : TEXCOORD3;

    #if defined(_FOG_FRAGMENT)
    half fogFactor : TEXCOORD4;
    #endif

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    float4 shadowCoord : TEXCOORD5;
    #endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 6);
    #ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD7;
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

float2 generateDir(float2 p)
{
    p = p % 289;
    float x = (34 * p.x + 1) * p.x % 289 + p.y;
    x = (34 * x + 1) * x % 289;
    x = frac(x / 41) * 2 - 1;
    return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
}

float generateNoise(float2 p)
{
    float2 ip = floor(p);
    float2 fp = frac(p);

    const float d00 = dot(generateDir(ip), fp);
    const float d01 = dot(generateDir(ip + float2(0, 1)), fp - float2(0, 1));
    const float d10 = dot(generateDir(ip + float2(1, 0)), fp - float2(1, 0));
    const float d11 = dot(generateDir(ip + float2(1, 1)), fp - float2(1, 1));

    fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
    return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
}

inline float gradientNoise(const float2 UV, const float Scale)
{
    return generateNoise(UV * Scale) * 2.0f;
}

inline half2 tilingAndOffset(const float2 uv, const float2 tiling, const float2 offset)
{
    return uv * tiling + offset;
}

InputData createInputData(const v2f input)
{
    InputData inputData = (InputData)0;

    inputData.positionWS = input.positionWS;

    half3 viewDirWS = GetWorldSpaceViewDir(inputData.positionWS);
    inputData.normalWS = input.normalWS;

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    viewDirWS = SafeNormalize(viewDirWS);

    inputData.viewDirectionWS = viewDirWS;

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
    inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = InitializeInputDataFog(float4(inputData.positionWS, 1.0), input.fogFactor);
    inputData.vertexLighting = half3(0, 0, 0);

    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV, input.vertexSH, inputData.normalWS);
    #else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    #endif

    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    return inputData;
}

float4 animateFlag(const float2 uv, const float4 positionOS)
{
    const half animationSpeed = _Time.y * _AnimationSpeedMultiplier;
    const half2 gradientUV = tilingAndOffset(
        GetAbsolutePositionWS(TransformObjectToWorld(positionOS.xyz)).xy,
        float2(1, 1),
        animationSpeed.xx);
    const half noise = gradientNoise(gradientUV, _NoiseStrength);
    const half4x4 m = UNITY_MATRIX_M;
    const half3 objectScale = half3(
        length(half3(m[0].x, m[1].x, m[2].x)),
        length(half3(m[0].y, m[1].y, m[2].y)),
        length(half3(m[0].z, m[1].z, m[2].z)));
    half4 displacementMapUV = SAMPLE_TEXTURE2D_LOD(_DisplacementMap, sampler_DisplacementMap, uv.xy, 0) * _DisplacementMapMultiplier;
    half3 newUV = displacementMapUV.xyz * objectScale * noise;
    const half displacementX = newUV.x + positionOS.x;
    const half displacementY = newUV.y * _OffsetStrengthY + positionOS.y;
    const half displacementZ = positionOS.z;

    return float4(displacementX, displacementY, displacementZ, 0);
}

v2f vert(appdata v)
{
    v2f output = (v2f)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, output);

    v.positionOS = animateFlag(v.uv, v.positionOS);

    const VertexPositionInputs vertexInput = GetVertexPositionInputs(v.positionOS.xyz);
    const VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, v.tangentOS);

    #if defined(_FOG_FRAGMENT)
    half fogFactor = 0;
    #else
    half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    #endif

    output.uv = TRANSFORM_TEX(v.uv, _BaseMap);
    output.positionWS.xyz = vertexInput.positionWS;
    output.positionCS = vertexInput.positionCS;

    output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);

    OUTPUT_LIGHTMAP_UV(v.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    #ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = v.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
    OUTPUT_SH(output.normalWS.xyz, output.vertexSH);

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    output.shadowCoord = GetShadowCoord(vertexInput);
    #endif

    output.fogFactor = fogFactor;
    
    return output;
}

half4 frag(v2f i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);

    const SurfaceData surfaceData = createSurfaceData(i.uv);
    const InputData inputData = createInputData(i);
    half4 outputColor = UniversalFragmentBlinnPhong(inputData, surfaceData);
    outputColor.rgb = MixFog(outputColor.rgb, inputData.fogCoord);

    return outputColor;
}
#endif