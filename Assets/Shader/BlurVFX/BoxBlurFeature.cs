using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class BoxBlurFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class BlurSettings
    {
        public Material blurMaterial;
        [Range(1, 6)] public int maxIterations = 4;
    }

    public BlurSettings settings = new BlurSettings();
    private BlurPass blurPass;

    public override void Create()
    {
        blurPass = new BlurPass(settings);
        // run before transparent objects
        blurPass.renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // skip preview cameras to prevent errors
        if (renderingData.cameraData.cameraType == CameraType.Preview) return;
        
        if (settings.blurMaterial != null) renderer.EnqueuePass(blurPass);
    }
}

class BlurPass : ScriptableRenderPass
{
    private BoxBlurFeature.BlurSettings settings;
    private RTHandle source;
    private int[] rtIDs;
    private int clearTexID;

    public BlurPass(BoxBlurFeature.BlurSettings settings)
    {
        this.settings = settings;
        
        // init temp RT arrays
        rtIDs = new int[settings.maxIterations];
        for (int i = 0; i < settings.maxIterations; i++) 
        {
            rtIDs[i] = Shader.PropertyToID("_BlurTemp" + i);
        }
        
        clearTexID = Shader.PropertyToID("_GlobalClearTex");
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        source = renderingData.cameraData.renderer.cameraColorTargetHandle;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        // safety check: prevent assertion failed when RT is not ready
        if (source == null || source.rt == null) return;

        CommandBuffer cmd = CommandBufferPool.Get("Global Box Blur");
        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.depthBufferBits = 0;

        // 1. capture clear screen
        cmd.GetTemporaryRT(clearTexID, desc, FilterMode.Point);
        cmd.Blit(source, clearTexID);
        cmd.SetGlobalTexture("_GlobalClearTex", clearTexID);

        int width = desc.width / 2;
        int height = desc.height / 2;
        RenderTargetIdentifier currentSource = source;

        // 2. downsample loop
        for (int i = 0; i < settings.maxIterations; i++)
        {
            desc.width = width;
            desc.height = height;
            cmd.GetTemporaryRT(rtIDs[i], desc, FilterMode.Bilinear);
            cmd.Blit(currentSource, rtIDs[i], settings.blurMaterial, 0);
            
            currentSource = rtIDs[i];
            width = Mathf.Max(width / 2, 1);
            height = Mathf.Max(height / 2, 1);
        }

        // 3. upsample loop
        for (int i = settings.maxIterations - 2; i >= 0; i--)
        {
            cmd.Blit(currentSource, rtIDs[i], settings.blurMaterial, 1);
            currentSource = rtIDs[i];
        }

        // 4. set max blurred texture
        cmd.SetGlobalTexture("_GlobalBlurredTex", currentSource);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public override void OnCameraCleanup(CommandBuffer cmd)
    {
        // free memory
        cmd.ReleaseTemporaryRT(clearTexID);
        for (int i = 0; i < settings.maxIterations; i++) 
        {
            cmd.ReleaseTemporaryRT(rtIDs[i]);
        }
    }
}