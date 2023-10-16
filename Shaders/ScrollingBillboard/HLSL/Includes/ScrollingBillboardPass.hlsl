#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

struct appdata
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
    float2 noiseUV : TEXCOORD1;

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_ScrollMap);
SAMPLER(sampler_ScrollMap);

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _ScrollMap_ST;
    half _ScrollY;
    half _ScrollMapAlpha;
    half _ScrollSpeedMultiplier;
CBUFFER_END

#ifdef UNITY_DOTS_INSTANCING_ENABLED
    UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)
        UNITY_DOTS_INSTANCE_PROP(float, _ScrollY)
        UNITY_DOTS_INSTANCE_PROP(float, _ScrollMapAlpha)
        UNITY_DOTS_INSTANCE_PROP(float, _ScrollSpeedMultiplier)
    UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)

    #define _ScrollY UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_ScrollY)
    #define _ScrollMapAlpha UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_ScrollMapAlpha)
    #define _ScrollSpeedMultiplier UNITY_ACCES_DOTS_INSTANCED_PROP_FROM_MACRO(float , Metadata_ScrollSpeedMultiplier)
#endif

v2f vert(appdata v)
{
    v2f o = (v2f)0;

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    
    o.vertex = TransformObjectToHClip(v.vertex);
    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

    o.noiseUV = TRANSFORM_TEX(v.uv, _ScrollMap);

    #if _SCROLL_Y
    o.noiseUV.y = o.noiseUV.y + (_Time.x * _ScrollSpeedMultiplier);
    #else
    o.noiseUV.x = o.noiseUV.x + (_Time.x * _ScrollSpeedMultiplier);
    #endif

    return o;
}

half4 frag(v2f i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);
    
    const half3 baseMapSample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).rgb;
    const half3 scrollMapSample = SAMPLE_TEXTURE2D(_ScrollMap, sampler_ScrollMap, i.noiseUV).rgb;

    half3 outputColor = lerp(baseMapSample, scrollMapSample, _ScrollMapAlpha);
    return half4(outputColor, 1.0f);
}
