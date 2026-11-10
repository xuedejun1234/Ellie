using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;
using Object = UnityEngine.Object;

public class DDStoPNG : EditorWindow
{
    [SerializeField] private List<Texture2D> dds = new();
    [SerializeField] private List<Texture2D> pngs = new();
    private SerializedObject _serializedObject;
    private SerializedProperty _serializedProperty;
    private SerializedObject _serializedObject1;
    private SerializedProperty _serializedProperty1;
    private Vector2 _scrollPosition;
    private Vector2 _scrollPosition1;

    [MenuItem("Tools/纹理相关/DDS to PNG")]
    public static void ShowWindow()
    {
        var window = GetWindow(typeof(DDStoPNG), false, "DDS to PNG");
        window.Show();
    }

    private void OnEnable()
    {
        _serializedObject = new SerializedObject(this);
        _serializedProperty = _serializedObject.FindProperty("dds");
        _serializedObject1 = new SerializedObject(this);
        _serializedProperty1 = _serializedObject1.FindProperty("pngs");
    }

    private void OnGUI()
    {
        _scrollPosition = EditorGUILayout.BeginScrollView(_scrollPosition);
        _serializedObject.Update();
        EditorGUILayout.PropertyField(_serializedProperty, true);
        _serializedObject.ApplyModifiedProperties();
        EditorGUILayout.EndScrollView();
        GUILayout.Space(20);
        GetAllDDS();
        GUILayout.Space(20);
        _scrollPosition1 = EditorGUILayout.BeginScrollView(_scrollPosition1);
        _serializedObject1.Update();
        EditorGUILayout.PropertyField(_serializedProperty1, true);
        _serializedObject1.ApplyModifiedProperties();
        EditorGUILayout.EndScrollView();
        GUILayout.FlexibleSpace();
        ConvertWithReadWriteTex();
    }

    private void OnDisable()
    {
        _serializedObject.Dispose();
        _serializedObject1.Dispose();
        dds.Clear();
        pngs.Clear();
    }

    private void GetAllDDS()
    {
        if (!GUILayout.Button("获取工程内所有DDS纹理", new GUIStyle(GUI.skin.button) { fontSize = 15 })) return;
        dds.Clear();
        var files = Directory.GetFiles(Application.dataPath, "*.dds", SearchOption.AllDirectories);
        if (files.Length is 0)
        {
            EditorUtility.DisplayDialog("提示", "工程内没有DDS纹理", "确定");
            return;
        }

        foreach (var file in files)
        {
            var path = file.Replace(Application.dataPath, "Assets");
            var texture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            if (AssetDatabase.GetAssetPath(texture).Contains(".dds"))
            {
                dds.Add(texture);
            }
            else
            {
                return;
            }
        }
    }

    private void ConvertWithReadWriteTex()
    {
        if (!GUILayout.Button("Convert", new GUIStyle(GUI.skin.button) { fontSize = 25 })) return;
        if (dds.Count is 0)
        {
            EditorUtility.DisplayDialog("提示", "请先获取工程内所有DDS纹理", "确定");
            return;
        }

        for (var index = dds.Count - 1; index >= 0; index--)
        {
            var texture = dds[index];
            var readTexture = IsReadTexture(texture);
            var bytes = readTexture.EncodeToPNG();
            var ddsPath = AssetDatabase.GetAssetPath(texture);
            var ddsGuid = AssetDatabase.AssetPathToGUID(ddsPath);
            var pngPath = ddsPath.Replace(".dds", ".png");
            var pngFullPath = Path.GetFullPath(pngPath);

            if (Path.GetExtension(pngPath) != "")
            {
                File.WriteAllBytes(pngFullPath, bytes);
                AssetDatabase.DeleteAsset(ddsPath);
                AssetDatabase.Refresh();
                AssetDatabase.SaveAssets();
                var pngGuid = AssetDatabase.AssetPathToGUID(pngPath);
                var pngMetaPath = pngFullPath + ".meta";
                var content = File.ReadAllText(pngMetaPath);
                if (Regex.IsMatch(content, pngGuid))
                {
                    Debug.Log("替换了资源的路径:" + pngFullPath,
                        AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(pngFullPath)));
                    content = content.Replace(pngGuid, ddsGuid);
                    File.WriteAllText(pngMetaPath, content);
                }
                else
                {
                    Debug.Log("查看了资源的路径:" + pngFullPath);
                }

                dds.Remove(texture);
                AssetDatabase.Refresh();
                var png = AssetDatabase.LoadAssetAtPath<Texture2D>(pngPath);
                AssetDatabase.SaveAssetIfDirty(png);
                pngs.Add(png);
                Debug.Log("转换了纹理:" + pngFullPath,
                    AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(pngFullPath)));
            }
            else
            {
                Debug.Log("当前路径下有同名文件:" + pngFullPath,
                    AssetDatabase.LoadAssetAtPath<Object>(GetRelativeAssetsPath(pngFullPath)));
            }
        }
    }

    private void OnInspectorUpdate()
    {
        Repaint();
    }

    private static string GetRelativeAssetsPath(string path)
    {
        return "Assets" + Path.GetFullPath(path).Replace(Path.GetFullPath(Application.dataPath), "").Replace('\\', '/');
    }

    private static Texture2D IsReadTexture(Texture texture2D)
    {
        var temp = RenderTexture.GetTemporary(texture2D.width, texture2D.height, 0, RenderTextureFormat.ARGB32,
            RenderTextureReadWrite.Default);
        Graphics.Blit(texture2D, temp);
        var previous = RenderTexture.active;
        RenderTexture.active = temp;
        var myTexture2D = new Texture2D(texture2D.width, texture2D.height, TextureFormat.ARGB32, false);
        myTexture2D.ReadPixels(new Rect(0, 0, temp.width, temp.height), 0, 0);
        myTexture2D.Apply();
        RenderTexture.active = previous;
        RenderTexture.ReleaseTemporary(temp);
        return myTexture2D;
    }
}