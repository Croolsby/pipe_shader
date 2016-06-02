// Given two points as a line, 
Shader "Custom/PipeShader" {
    Properties{
        _Radius("Radius", Range(0, 1)) = 0.1
    }

    SubShader {
        Pass{
            Tags{
                "Queue" = "Geometry"
                "RenderType" = "Opaque"
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom
            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct v2g {
                float4  position: POSITION; // the spine point
                float3  normal  : NORMAL; // the normal of the plane the ring to be generated around each spine point lies in.
                float4  tangent : TANGENT; // a vector that points from the spine point to a point on the ring.
                float4  color   : COLOR; // the color
            };

            struct g2f {
                float4  position  : POSITION;
                float4  color     : COLOR;
            };

            static const float PI = 3.14159;
            float _Radius;

            v2g vert(appdata_full v) {
                v2g o;
                // put everything in world space
                o.position = mul(_Object2World, v.vertex);
                o.normal = mul(_Object2World, float4(v.normal, 1)).xyz;
                o.tangent = mul(_Object2World, v.tangent);
                o.color = v.color;
                return o;
            }

            float3 triNormal(float3 tri[3]) {
                float3 a = tri[0] - tri[1];
                float3 b = tri[2] - tri[1];
                float3 c = cross(a, b);
                if (length(c) == 0) {
                    return float3(0, 0, 0);
                } else {
                    return normalize(c);
                }
            }

            float4 quaternion(float angle, float3 axis) {
                float3 ax = normalize(axis) * sin(angle / 2.0f);
                return float4(ax.x, ax.y, ax.z, cos(angle / 2.0f));
            }

            float3x3 rotation(float4 q) {
                float3x3 result = {1 - 2*q.y*q.y - 2*q.z*q.z, 2*q.x*q.y - 2*q.z*q.w, 2*q.x*q.z + 2*q.y*q.w,
                    2*q.x*q.y + 2*q.z*q.w, 1 - 2*q.x*q.x - 2*q.z*q.z, 2*q.y*q.z - 2*q.x*q.w,
                    2*q.x*q.z - 2*q.y*q.w, 2*q.y*q.z + 2*q.x*q.w, 1 - 2*q.x*q.x - 2*q.y*q.y};
                    return result;
                }

                #define DIVS 8 // the number of faces the cylinder will have
                [maxvertexcount(32)] // maxvertexcount(DIVS * 4)
                void geom(line v2g p[2], inout TriangleStream<g2f> triStream) {
                    float4 v0[DIVS]; // output vertices
                    float4 v1[DIVS];
                    float3 tangent0 = p[0].tangent.xyz;
                    float3 tangent1 = p[1].tangent.xyz;
                    float radius0 = p[0].tangent.w;
                    float radius1 = p[1].tangent.w;

                    // create rotators
                    float3x3 rotation0 = rotation(quaternion(2.0f * PI / DIVS, p[0].normal));
                    float3x3 rotation1 = rotation(quaternion(2.0f * PI / DIVS, p[1].normal));
                    // float3x3 rotation2 = rotation(quaternion(2.0f * PI / 10, p[2].normal));

                    // create rings
                    for (int i = 0; i < DIVS; i++) {
                        v0[i] = float4(p[0].position.xyz + radius0 * tangent0, 1.0f);
                        v1[i] = float4(p[1].position.xyz + radius1 * tangent1, 1.0f);
                        // v2[i] = float4(p[2].pos.xyz + radius2 * tangent2, 1.0f);

                        // rotate tangent around normal
                        tangent0 = mul(rotation0, tangent0);
                        tangent1 = mul(rotation1, tangent1);
                        // tangent2 = mul(rotation2, tangent2);
                    }

                    float4 sv0[DIVS];
                    float4 sv1[DIVS];
                    // convert to screen space from world space
                    for (int i = 0; i < DIVS; i++) {
                        sv0[i] = mul(UNITY_MATRIX_VP, v0[i]);
                        sv1[i] = mul(UNITY_MATRIX_VP, v1[i]);
                    }

                    // output triangle strip shell
                    g2f o;
                    UNITY_INITIALIZE_OUTPUT(g2f, o);
                    o.color.w = 1;
                    float3 tri[3];
                    float3 normal0 = {0 ,0, 0};
                    float3 normal1 = {0, 0, 0};
                    float3 normal = {0, 0, 0};
                    float dotLightNormal;
                    for (int i = 0; i < DIVS; i++) {

                        // tri[0] = v0[i];
                        // tri[1] = v1[1];
                        // tri[2] = v0[(i + 1) % 10];
                        // normal0 = -triNormal(tri);

                        // tri[0] = v1[i];
                        // tri[1] = v1[(i + 1) % 10];
                        // tri[2] = v0[(i + 1) % 10];
                        // normal1 = -triNormal(tri);

                        // normal = (normal0 + normal1) / 2;
                        // dotLightNormal = max(0, dot(normalize(_WorldSpaceLightPos0.xyz), normal));
                        // dotLightNormal = 1;

                        tri[0] = v0[i].xyz;
                        tri[1] = v1[i].xyz;
                        tri[2] = v0[(i + 1) % DIVS].xyz;
                        normal0 = -triNormal(tri);

                        tri[0] = v1[i];
                        tri[1] = v1[(i + 1) % DIVS];
                        tri[2] = v0[(i + 1) % DIVS];
                        normal1 = -triNormal(tri);

                        normal = normalize(normal0 + normal1);
                        dotLightNormal = max(0, dot(normalize(_WorldSpaceLightPos0.xyz), normal));

                        o.position = sv0[i];
                        o.color.xyz = p[0].color * dotLightNormal;
                        triStream.Append(o);

                        o.position = sv1[i];
                        o.color.xyz = p[1].color * dotLightNormal;
                        triStream.Append(o);

                        o.position = sv0[(i + 1) % DIVS];
                        o.color.xyz = p[0].color * dotLightNormal;
                        triStream.Append(o);

                        o.position = sv1[(i + 1) % DIVS];
                        o.color.xyz = p[1].color * dotLightNormal;
                        triStream.Append(o);

                        triStream.RestartStrip();

                        // tri[0] = v1[i];
                        // tri[1] = v1[(i + 1) % DIVS];
                        // tri[2] = v0[(i + 1) % DIVS];
                        // normal = -triNormal(tri);
                        // dotLightNormal = max(0, dot(normalize(_WorldSpaceLightPos0.xyz), normal));

                        // o.position = sv1[i];
                        // o.color.xyz = p[1].color * dotLightNormal;
                        // triStream.Append(o);

                        // o.position = sv1[(i + 1) % DIVS];
                        // o.color.xyz = p[1].color * dotLightNormal;
                        // triStream.Append(o);

                        // o.position = sv0[(i + 1) % DIVS];
                        // o.color.xyz = p[0].color * dotLightNormal;
                        // triStream.Append(o);

                        // triStream.RestartStrip();    
                    }

                    // float3 up = float3(0, 1, 0);
                    // float3 look;
                    // float3 right;
                    // float3 triCenter;
                    // o.position.w = 1;
                    // o.color = float4(1, 1, 1, 1);
                    // for (int i = 0; i < 4; i++) {
                    //     tri[0] = v0[i];
                    //     tri[1] = v1[i];
                    //     tri[2] = v0[(i + 1) % 5];
                    //     normal = -triNormal(tri);

                    //     triCenter = (tri[0] + tri[1] + tri[2]) / 3;
                    //     look = _WorldSpaceCameraPos - triCenter;
                    //     look = normalize(look);

                    //     right = cross(normal, look);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter - 0.001 * right, 1));
                    //     triStream.Append(o);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter + 0.001 * right, 1));
                    //     triStream.Append(o);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter - 0.001 * right + 0.1 * normal, 1));
                    //     triStream.Append(o);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter + 0.001 * right + 0.1 * normal, 1));
                    //     triStream.Append(o);

                    //     triStream.RestartStrip();

                    //     tri[0] = v1[i];
                    //     tri[1] = v1[(i + 1) % 5];
                    //     tri[2] = v0[(i + 1) % 5];
                    //     normal = -triNormal(tri);

                    //     triCenter = (tri[0] + tri[1] + tri[2]) / 3;
                    //     look = _WorldSpaceCameraPos - triCenter;
                    //     look = normalize(look);

                    //     right = cross(up, look);
                    //     up = cross(look, right);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter - 0.001 * right, 1));
                    //     triStream.Append(o);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter + 0.001 * right, 1));
                    //     triStream.Append(o);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter - 0.001 * right + 0.1 * normal, 1));
                    //     triStream.Append(o);

                    //     o.position = mul(UNITY_MATRIX_VP, float4(triCenter + 0.001 * right + 0.1 * normal, 1));
                    //     triStream.Append(o);

                    //     triStream.RestartStrip();
                    // }
                }

                

                float4 frag(g2f f) : COLOR {
                    float3 ambient = saturate(UNITY_LIGHTMODEL_AMBIENT + f.color);
                    return float4(ambient, 1);
                }

                ENDCG
                } // pass
                } // subshader
            }
