Shader "Custom/FrostedGlass"
{
    Properties
    {
        // 0 = completely clear, 1 = max blur
        _BlurStrength ("Blur Strength", Range(0, 1)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                float4 screenPos : TEXCOORD0; 
            };

            // get both textures from C#
            TEXTURE2D(_GlobalClearTex);
            SAMPLER(sampler_GlobalClearTex);

            TEXTURE2D(_GlobalBlurredTex);
            SAMPLER(sampler_GlobalBlurredTex);
            
            float _BlurStrength;

            v2f vert(appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.screenPos = ComputeScreenPos(o.positionCS); 
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                
                // sample both clear and blurred textures
                half4 clearCol = SAMPLE_TEXTURE2D(_GlobalClearTex, sampler_GlobalClearTex, screenUV);
                half4 blurCol = SAMPLE_TEXTURE2D(_GlobalBlurredTex, sampler_GlobalBlurredTex, screenUV);
                
                // blend based on slider
                return lerp(clearCol, blurCol, _BlurStrength);
            }
            ENDHLSL
        }
    }
}