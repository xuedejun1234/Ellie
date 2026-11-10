using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SkinSSSRenderFeature : ScriptableRendererFeature
{
    class SkinSSSRenderPass : ScriptableRenderPass
    {
        private RenderTargetHandle source;
        private RenderTargetHandle specularTargetHandle;
        public Material material;
        public Color sssColor;
        public float blurSize;
        public string shaderName;
        
        
        
        static readonly int SkinMaskTextureId = Shader.PropertyToID("_SkinMaskTexture");
        static readonly int SourceTextureId   = Shader.PropertyToID("_SourceTexture");
        static readonly int SkinSpecTextureId = Shader.PropertyToID("_SkinSpecTexture");
        
        //原图存储
        private RenderTargetHandle sourceRT;
        private RenderTargetHandle tempRT0;
        private RenderTargetHandle tempRT1;

        private string m_ProfilerTag = "SkinSSS Draw Pass";

        public SkinSSSRenderPass(Material material, string shaderName)
        {
            this.material = material;
            this.shaderName = shaderName;
            //Init
            sourceRT.Init("_SourceTexture");
            tempRT0.Init("_TemporaryRenderTexture0");
            tempRT1.Init("_TemporaryRenderTexture1");
        }
        //初始化
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            if(material == null)
                material = CoreUtils.CreateEngineMaterial(shaderName);//ShaderName
            cmd.GetTemporaryRT(tempRT0.id, cameraTextureDescriptor, FilterMode.Bilinear);
            cmd.GetTemporaryRT(tempRT1.id, cameraTextureDescriptor, FilterMode.Bilinear);
            //这里将原图像copy到sourceTexture中，后面做叠加使用
            int sourceRT = Shader.PropertyToID("_SourceTexture");
            cmd.GetTemporaryRT(sourceRT, cameraTextureDescriptor);
            
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (material == null)
            {
                Debug.LogError("Material is null!");
                return;
            }
            
            //Src
            source = new RenderTargetHandle(renderingData.cameraData.renderer.cameraColorTarget);
            
            RenderTextureDescriptor opaqueDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDescriptor.depthBufferBits = 0;
            //模糊半径
            material.SetFloat("_BlurSize", blurSize);
            //SSS颜色
            material.SetColor("_Color", sssColor);
            
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            cmd.Blit(source.Identifier(), sourceRT.Identifier());

            using (new ProfilingScope(cmd, new ProfilingSampler(m_ProfilerTag)))
            {
                //模糊
                cmd.Blit(source.Identifier(), tempRT0.Identifier());
                for (int i = 0; i < 2; i++)
                {
                    cmd.Blit(tempRT0.Identifier(), tempRT1.Identifier(), material, 0);
                    cmd.Blit(tempRT1.Identifier(), tempRT0.Identifier(), material, 1);
                }
            
                cmd.SetGlobalTexture(SourceTextureId,   sourceRT.Identifier());
                cmd.Blit(tempRT0.Identifier(), source.Identifier(), material, 2);
            }
            
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();
            CommandBufferPool.Release(cmd);
            
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(sourceRT.id);
            cmd.ReleaseTemporaryRT(tempRT0.id);
            cmd.ReleaseTemporaryRT(tempRT1.id);
        }
        
    }
    
    SkinSSSRenderPass m_ScriptablePass;

    private const string shaderName = "Hidden/PostProcess/SkinSSS";
    private Material material = null;
    public Color sssColor = Color.red;
    public float blurSize = 1.0f;
    
    

    public override void Create()
    {
        m_ScriptablePass = new SkinSSSRenderPass(material, shaderName);
        m_ScriptablePass.renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
        m_ScriptablePass.blurSize = blurSize;
        m_ScriptablePass.sssColor = sssColor;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);
    }
}
