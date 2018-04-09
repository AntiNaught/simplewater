// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Anty/Water/SimpleWater_bug"
{
	Properties
	{
		_ColorTint("Main Color",Color) = (1,1,1,1)
		_Specular("Specular Color",Color) = (0,0,0,0)
		_Gloss("Gloss",Range(1,20)) = 2 
		_Diffuse("Diffuse",2D) = "white"{}
		_Normal("Normal",2D) = "white"{}
		L("L",Float) 	= 1		// 振幅
		A("A",Float) 	= 1		// 波速（这个和水流速度无关）
	 	S("S",Float) 	= 1		
		PI("PI",Float) = 3.14159
	}	

	SubShader
	{
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

			float L;	//波长 （m）
			float A;	//振幅 （m）
			float S; 	//波速 （m/s）
			float PI;

			uniform	float3 C;	//方向波的波心(波源)
			struct v2f
			{
				// float4 color:COLOR;
				float4 vertex:SV_POSITION;
				float4 uv:TEXCOORD0;
				float4 WT0:TEXCOORD1;
				float4 WT1:TEXCOORD2;
				float4 WT2:TEXCOORD3;
			};

			struct param
			{
				float4 worldPos;
				float3 normal;
				float3 biNormal;
				float3 tangent;
			};

			//单一的方向波
			float GetVertPos(float4 vertex)
			{
				float w = 2 * PI / L;	//角频率(degree/m)
				float psi = S * w;	//角速度(degree/s)
				float3 d = normalize(vertex.xyz - C);	//垂直于波阵面的水平向量（波运动方向），分量 y = 0
				float height = A * sin(dot(d.xz,vertex.xz) * w + _Time.y * psi);	//波1	//因为 W 的值恰好 = 2π ，导致同一个波传播方向上的各个点的相位相同，所以啧啧啧  L=1 和 L=4 是完全不一样的
				return height;
			}

			param CalculateParam(float4 vertex)
			{
				param pa;
				float w = 2 * PI / L;	//角频率(degree/m)
				float psi = S * w;	//角速度(degree/s)
				float3 d = normalize(vertex.xyz - C);	//垂直于波阵面的水平向量（波运动方向），分量 y = 0
				float u = dot(d.xz,vertex.xz) * w + _Time.y * psi;
				float height = A * cos(u);	//波1
				pa.worldPos =float4(vertex.x ,height, vertex.z , vertex.w);	//波1

				// 计算normal binormal tangent
				float theta = dot(d.xz,vertex.xz) / (length(d) * length(float2(vertex.xz))); 
				float pre_ = A * cos(dot(d.xz,vertex.xz) * w + _Time.y * psi) * length(d) * cos(theta) * w / length(float2(vertex.xz));
				float by = pre_ * vertex.x;	//副法线y
				float ty = pre_ * vertex.z;	//切线y
				pa.biNormal = float3(1,by,0);
				pa.tangent 	= float3(0,ty,1);
				pa.normal 	= cross(pa.biNormal,pa.tangent);
				return pa;
			}

			v2f vert(appdata_tan v)
			{
				v2f o;
				param p = CalculateParam(v.vertex);
				float4 pos = v.vertex;
				pos.y = GetVertPos(v.vertex);
				// o.vertex = UnityObjectToClipPos(p.worldPos);
				o.vertex = UnityObjectToClipPos(pos);
				o.uv = v.texcoord;
				o.WT0 = float4(p.normal.x,p.biNormal.x,p.tangent.x,p.worldPos.x);
				o.WT1 = float4(p.normal.y,p.biNormal.y,p.tangent.y,p.worldPos.y);
				o.WT2 = float4(p.normal.z,p.biNormal.z,p.tangent.z,p.worldPos.z);
				// normal binormal tangent pos
				return o;
			}

			float4 frag(v2f i):SV_TARGET
			{
				//组装 我为什么要把切线坐标系的三个基都搞过来呢，我又不用切线空间的法线贴图，我只是用一个法线啊,哦对，我需要切线空间和世界空间的变换(好在书上的公式都描述的是世界空间下的)
				float3 normal 	= float3(i.WT0.x,i.WT1.x,i.WT2.x);
				float3 worldPos = float3(i.WT0.w,i.WT1.w,i.WT2.w);
				//uv
				i.uv.xy = i.uv.xy * _Diffuse_ST.xy + _Diffuse_ST.zw;
				// i.uv.x = i.uv.x + _Time.y;
				//albedo
				fixed3 albedo = tex2D(_Diffuse,i.uv.xy).rgb;
				//diffuse
				fixed3 worldLightDir = _WorldSpaceLightPos0.xyz - worldPos;
				fixed4 diffuse = fixed4(albedo,1); // * _LightColor0;
				// fixed4 diffuse = fixed4(_LightColor0.rgb * albedo * max(0,dot(worldLightDir,normal)),1);

				fixed4 specular = (0,0,0,0);
				return diffuse + specular; 

				//specular
				//fresnil
			}
			ENDCG
		}
	}

	Fallback "DIFFUSE"
}

// step 1 : 逐顶点叠加波 √ 								效果很蛋疼，顶点太疏
//		step 1_1 : 法线计算，diffuse、specular
//		step 1_2 : procedural 更密集的 mesh
// step 2 : 流动效果（uv偏移）
// step 3 : fresnil
// step 4 : 波面反射
// step 5 : 波的扰动（方向波的多个波源产生的叠加效果）
// step 6 : 