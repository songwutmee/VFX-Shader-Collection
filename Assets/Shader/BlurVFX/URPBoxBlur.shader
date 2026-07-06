Shader "Hidden/URPBoxBlur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        float4 _MainTex_TexelSize;

        struct appdata
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        v2f vert(appdata v)
        {
            v2f o;
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
            o.uv = v.uv;
            return o;
        }

        // sample 4 adjacent pixels for box blur
        half4 BoxBlur(float2 uv, float scale)
        {
            float2 offset = _MainTex_TexelSize.xy * scale;
            half4 col = 0;
            
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-offset.x, -offset.y));
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(offset.x, -offset.y));
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(-offset.x, offset.y));
            col += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + float2(offset.x, offset.y));
            
            return col * 0.25h; // average color
        }
        ENDHLSL

        // Pass 0: downsample
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            half4 frag(v2f i) : SV_Target { return BoxBlur(i.uv, 1.0); }
            ENDHLSL
        }

        // Pass 1: upsample (use half-pixel scale)
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            half4 frag(v2f i) : SV_Target { return BoxBlur(i.uv, 0.5); }
            ENDHLSL
        }
    }
}