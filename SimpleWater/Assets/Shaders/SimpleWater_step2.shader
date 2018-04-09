// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Anty/Water/SimpleWater_step2"
{
	Properties
	{
		_ColorTint("Main Color",Color) = (1,1,1,1)
		_Specular("Specular Color",Color) = (0,0,0,0)
		_Gloss("Gloss",Range(1,20)) = 2 
		_Diffuse("Diffuse",2D) = "white"{}
		_Normal("Normal",2D) = "white"{}
		Q("Q",Range(0,1)) = 0.5 // 波陡的程度
		L("L",Float) 	= 1		// 振幅
		A("A",Float) 	= 1		// 波速（这个和水流速度无关）
	 	S("S",Float) 	= 1		
		PI("PI",Float) = 3.14159
	}	

	SubShader
	{
		Tags{"Light Mode" = "ForwardBase"}
		pass
		{
			CGPROGRAM
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#pragma vertex vert 
			#pragma fragment frag 

			sampler2D _Diffuse;
			float4 _Diffuse_ST;	
			sampler2D _Normal;

			float Q;
			float L;	//波长 （m）
			float A;	//振幅 （m）
			float S; 	//波速 （m/s）
			float PI;

			struct v2f
			{
				float4 color:COLOR;
				float4 vertex:SV_POSITION;
				float4 uv:TEXCOORD0;
				float4 WT0:TEXCOORD1;
				float4 WT1:TEXCOORD2;
				float4 WT2:TEXCOORD3;
			};

			struct param
			{
				float4 worldPos;
				float3 worldNormal;
				float3 worldBiNormal;
				float3 worldTangent;
			};

			//gerstner 波，顶点位置和法线
			param CalculateParam(float4 vertex)
			{
				param pa;
				float g = 9.8;																//重力加速度(m/s²)
				// float w = sqrt(g * 2 * PI / L);												//角频率(degree/m)	 忽略高次项的水的传播关系
				float w = (g * 2 * PI / L);												//角频率(degree/m)	 忽略高次项的水的传播关系
				float psi = S * w;															//角速度(degree/s)
				float3 d = float3(0,0,1);															//垂直于波阵面的水平向量（波运动方向），(风向)
				float u = dot(d.xz,vertex.xz) * w + _Time.y * psi;		
				float sinu,cosu;
				sincos(u,sinu,cosu);
				float px = vertex.x + Q * A * d.x * cosu;
				float pz = vertex.z + Q * A * d.z * cosu;
				float py = A * sinu;	//波1
				pa.worldPos = float4(px ,py, pz , vertex.w);
				pa.worldPos = mul(unity_ObjectToWorld,pa.worldPos);

				float sino,coso;
				sincos(w * dot(d,pa.worldPos) + psi * _Time.y,sino,coso);

				//书上并没有特定的左右手坐标系，只是书上的mesh面朝向z，这里把d.y换成d.z就可以了
				pa.worldNormal 		= normalize(UnityObjectToWorldDir (float3( - d.x * w * A * coso, - d.z * w * A * coso, 1 - Q * w * A * sino )));
				pa.worldBiNormal 	= normalize(UnityObjectToWorldDir (float3( 1 - Q * d.x * d.x * w * A * sino , - Q * d.x * d.z * w * A * sino , d.x * w * A * coso )));
				pa.worldTangent 	= normalize(UnityObjectToWorldDir (float3( -Q * d.x * d.z * w * A * sino , - 1 + Q * d.z * d.z * w * A * sino , d.z * w * A * coso)));

				return pa;
			}

			v2f vert(appdata_tan v)
			{
				v2f o;
				param p = CalculateParam(v.vertex);
				float4 pos = v.vertex;
				o.vertex = UnityObjectToClipPos(p.worldPos);
				
				// o.color = fixed4(-p.worldPos.y,p.worldPos.y,0,1);	//Debug 染色 ： 法线越向上，越绿，越向下越蓝
				o.color = fixed4(0,0,0,0);
				o.uv = v.texcoord;
				o.WT0 = float4(p.worldNormal.x,p.worldBiNormal.x,p.worldTangent.x,p.worldPos.x);
				o.WT1 = float4(p.worldNormal.y,p.worldBiNormal.y,p.worldTangent.y,p.worldPos.y);
				o.WT2 = float4(p.worldNormal.z,p.worldBiNormal.z,p.worldTangent.z,p.worldPos.z);
				return o;
			}

			// 法线的计算放在vertex shader 中的话，
			float4 frag(v2f i):SV_TARGET
			{
				//组装 我为什么要把切线坐标系的三个基都搞过来呢，我又不用切线空间的法线贴图，我只是用一个法线啊,哦对，我需要切线空间和世界空间的变换(好在书上的公式都描述的是世界空间下的)
				float3 worldNormal 	= float3(i.WT0.x,i.WT1.x,i.WT2.x);
				// float3 worldNormal 	= float3(i.WT0.y,i.WT1.y,i.WT2.y);
				// float3 worldNormal 	= float3(i.WT0.z,i.WT1.z,i.WT2.z);
				float3 worldPos 	= float3(i.WT0.w,i.WT1.w,i.WT2.w);
				//uv
				i.uv.xy = i.uv.xy * _Diffuse_ST.xy + _Diffuse_ST.zw;
				//albedo
				fixed4 albedo = tex2D(_Diffuse,i.uv.xy);
				//diffuse
				fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - worldPos);
				// WorldSpaceLightDir
				fixed4 diffuse = max(0,dot(normalize(WorldSpaceLightDir(float4(worldPos,1))),worldNormal)) * albedo * _LightColor0;

				// return fixed4(0,0,worldNormal.y,1);
				float3 normalColor = worldNormal / 2 + float3(0.5,0.5,0.5);
				return fixed4(normalColor,1);
			}
			ENDCG
		}
	}
	Fallback "DIFFUSE"
}

// step 1 : 逐顶点叠加波 √ 效果很蛋疼，顶点太疏
// step 2 : 流动效果（uv偏移）√,尖浪(gerstner波)√,波长 ，波速
// step 3 : fresnil
// step 4 : 波的扰动（方向波的多个波源产生的叠加效果）
// step 5 : 波的衰减
//当波长足够长的时候，会出现我也不知道那个貌似收缩光环的效果
//step n : 计算法线