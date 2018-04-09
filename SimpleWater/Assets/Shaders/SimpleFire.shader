// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Shader "Anty/Water/SimpleFire_step1"
// {
// 	Properties
// 	{
		
// 	}	

// 	SubShader
// 	{
// 		pass
// 		{
// 			CGPROGRAM
// 			#include "UnityCG.cginc"
// 			#include "Lighting.cginc"
// 			#pragma vertex vert 
// 			#pragma fragment frag 

			


// 			ENDCG
// 		}
// 	}

// 	Fallback "DIFFUSE"
// }

// step 1 : 逐顶点叠加波 √ 								效果很蛋疼，顶点太疏
//		step 1_1 : 法线计算，diffuse、specular
//		step 1_2 : procedural 更密集的 mesh
// step 2 : 流动效果（uv偏移）
// step 3 : fresnil
// step 4 : 波面反射
// step 5 : 波的扰动（方向波的多个波源产生的叠加效果）
// step 6 : 