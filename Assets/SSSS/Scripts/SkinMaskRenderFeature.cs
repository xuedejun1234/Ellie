using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class SkinMaskRenderFeature : ScriptableRendererFeature
{
    class SkinMaskRenderPass : ScriptableRenderPass
    {
        private RenderTargetHandle skinMaskTargetHandle;

        private Material skinMaskMaterial = null;
        private FilteringSettings skinFilteringSetting;
        private FilteringSettings shelterFilteringSetting;
        private FilteringSettings hairShelterFilteringSetting;

        private string m_ProfilerTag = "SkinMask Draw Pass";
        ShaderTagId m_ShaderTagId = new ShaderTagId("UniversalForward");
        ShaderTagId m_HairShelterTagId = new ShaderTagId("SkinShelter");
        //设置筛选条件
        public SkinMaskRenderPass(RenderQueueRange renderQueueRange, LayerMask layerMask1,
            LayerMask layerMask2, Material material)
        {
            skinFilteringSetting = new FilteringSettings(renderQueueRange, layerMask1);
            shelterFilteringSetting = new FilteringSettings(
                new RenderQueueRange { lowerBound = 0, upperBound = 2449 }, layerMask2);
            hairShelterFilteringSetting = new FilteringSettings(
                new RenderQueueRange { lowerBound = 2450, upperBound = 2500 }, layerMask2);
            skinMaskMaterial = material;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)//第二个参数代表规格
        {
            skinMaskTargetHandle.Init("_SkinMasktexture");//分配ID
            cmd.GetTemporaryRT(skinMaskTargetHandle.id, cameraTextureDescriptor, FilterMode.Trilinear);// 按相机规格申请一张临时纹理
            ConfigureTarget(skinMaskTargetHandle.Identifier());//设置渲染目标
            ConfigureClear(ClearFlag.All, Color.black);//绘制蒙版前清理
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (skinMaskMaterial == null)
            {
                Debug.LogError("skinMaskMaterial is null");
                return;
            }
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            //ProfilingScope 是一个性能分析区间：它在进入代码块时开始记录，在离开时结束记录。
            //这里 m_Sampler 提供区间名称，`ProfilingScope` 把开始和结束标记写入 cmd。
            using (new ProfilingScope(cmd, new ProfilingSampler(m_ProfilerTag))) //离开代码块时自动结束,定义一条性能分析样本，最主要是给它一个名字
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                //定义默认排序关系
                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                
                var maskDrawSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
                maskDrawSettings.perObjectData = PerObjectData.None;
                maskDrawSettings.overrideMaterial = skinMaskMaterial;
                maskDrawSettings.overrideMaterialPassIndex = 0;
                context.DrawRenderers(renderingData.cullResults, ref maskDrawSettings, ref skinFilteringSetting);// 把筛选出的物体绘制到这张纹理上
                
                //绘制shelter遮挡
                var shelterdrawSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
                shelterdrawSettings.perObjectData = PerObjectData.None;
                shelterdrawSettings.overrideMaterial = skinMaskMaterial;
                shelterdrawSettings.overrideMaterialPassIndex = 1;
                context.DrawRenderers(renderingData.cullResults, ref shelterdrawSettings, ref shelterFilteringSetting);

                // Hair cards use their own alpha-clipped pass so empty texels do not cover the skin mask.
                var hairShelterDrawSettings = CreateDrawingSettings(m_HairShelterTagId, ref renderingData, sortFlags);
                hairShelterDrawSettings.perObjectData = PerObjectData.None;
                context.DrawRenderers(renderingData.cullResults, ref hairShelterDrawSettings,
                    ref hairShelterFilteringSetting);
                //设置全局变量
                cmd.SetGlobalTexture("_SkinMaskTexture", skinMaskTargetHandle.id);
            }
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(skinMaskTargetHandle.id);
        }
    }

    class SpecularRenderPass : ScriptableRenderPass
    {
        private RenderTargetHandle specularTargetHandle;
        private Material specularMaterial = null;
        private FilteringSettings skinFilteringSetting;
        private string m_ProfilerTag = "Specular Draw Pass";
        ShaderTagId m_ShaderTagId = new ShaderTagId("SkinSpecular");

        
        public SpecularRenderPass(RenderQueueRange renderQueueRange, LayerMask layerMask1,
             Material material)
        {
            skinFilteringSetting = new FilteringSettings(renderQueueRange, layerMask1);
            specularMaterial = material;
        }
        
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)//第二个参数代表规格
        {
            specularTargetHandle.Init("_SpecularRendertexture");//分配ID
            cmd.GetTemporaryRT(specularTargetHandle.id, cameraTextureDescriptor, FilterMode.Trilinear);// 按相机规格申请一张临时纹理
            ConfigureTarget(specularTargetHandle.Identifier());//设置渲染目标
            ConfigureClear(ClearFlag.All, Color.black);//绘制蒙版前清理
        }
        
        
        
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (specularMaterial == null)
            {
                Debug.LogError("specularMaterial is null");
                return;
            }
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            using (new ProfilingScope(cmd, new ProfilingSampler(m_ProfilerTag))) //离开代码块时自动结束,定义一条性能分析样本，最主要是给它一个名字
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();
                //定义默认排序关系
                var sortFlags = renderingData.cameraData.defaultOpaqueSortFlags;
                
                var maskDrawSettings = CreateDrawingSettings(m_ShaderTagId, ref renderingData, sortFlags);
                // maskDrawSettings.perObjectData = PerObjectData.None;
                maskDrawSettings.overrideMaterial = specularMaterial;
                maskDrawSettings.overrideMaterialPassIndex = 1;//高光pass
                context.DrawRenderers(renderingData.cullResults, ref maskDrawSettings, ref skinFilteringSetting);// 把筛选出的物体绘制到这张纹理上
                cmd.SetGlobalTexture("_SpecularRendertexture", specularTargetHandle.Identifier());
            }
            
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
        
        
        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(specularTargetHandle.id);
        }
    }
    
    
    
    public LayerMask mask;
    public LayerMask shelter;
    private SkinMaskRenderPass skinMaskPass;
    Material skinMaskMaterial;
    
    private SpecularRenderPass specularPass;
    public Material specularMaterial;
    
    public override void Create()
    {
        //遮罩
        skinMaskMaterial = CoreUtils.CreateEngineMaterial("Hidden/PostProcess/SkinMask");
        skinMaskPass = new SkinMaskRenderPass(RenderQueueRange.opaque, mask, shelter, skinMaskMaterial);
        skinMaskPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
        //高光
        
        specularPass = new SpecularRenderPass(RenderQueueRange.opaque, mask, specularMaterial);
        specularPass.renderPassEvent = RenderPassEvent.BeforeRenderingOpaques;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(skinMaskPass);
        renderer.EnqueuePass(specularPass);
    }
}
