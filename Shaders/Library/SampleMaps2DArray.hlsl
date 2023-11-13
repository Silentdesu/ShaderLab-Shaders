#ifndef SAMPLE_MAPS_2DARRAY_FUNCTIONS_INCLUDED
#define SAMPLE_MAPS_2DARRAY_FUNCTIONS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

half4 SampleSpecularSmoothness(
    float3 uv,
    half alpha,
    half4 specColor,
    TEXTURE2D_ARRAY_PARAM(specMap, sampler_specMap)
)
{
    half4 specularSmoothness = half4(0, 0, 0, 1);
    #ifdef _SPECGLOSSMAP
    specularSmoothness = SAMPLE_TEXTURE2D_ARRAY(specMap, sampler_specMap, uv.xy, uv.z) * specColor;
    #elif defined(_SPECULAR_COLOR)
    specularSmoothness = specColor;
    #endif

    #ifdef _GLOSSINESS_FROM_BASE_ALPHA
    specularSmoothness.a = alpha;
    #endif

    return specularSmoothness;
}

half3 SampleNormal(
    float3 uv,
    TEXTURE2D_ARRAY_PARAM(bumpMap, sampler_bumpMap),
    half scale = half(1.0))
{
#ifdef _NORMALMAP
    half4 n = SAMPLE_TEXTURE2D_ARRAY(bumpMap, sampler_bumpMap, uv.xy, uv.z);
    #if BUMP_SCALE_NOT_SUPPORTED
        return UnpackNormal(n);
    #else
        return UnpackNormalScale(n, scale);
    #endif
#else
    return half3(0.0h, 0.0h, 1.0h);
#endif
}

half3 SampleEmission(
    float3 uv,
    half3 emissionColor,
    TEXTURE2D_ARRAY_PARAM(emissionMap, sampler_emissionMap))
{
#ifndef _EMISSION
    return 0;
#else
    return SAMPLE_TEXTURE2D_ARRAY(emissionMap, sampler_emissionMap, uv.xy, uv.z).rgb * emissionColor;
#endif
}

half4 SampleAlbedoAlphaArray(float3 uv, TEXTURE2D_ARRAY_PARAM(albedoAlphaMap, sampler_albedoAlphaMap))
{
    return half4(SAMPLE_TEXTURE2D_ARRAY(albedoAlphaMap, sampler_albedoAlphaMap, uv.xy, uv.z));
}

#endif