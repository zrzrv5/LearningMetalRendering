//
//  MeshShader.metal
//  MeshShaderRender
//
//  Created by Rui Zhou on 6/24/24.
//

#include <metal_stdlib>
using namespace metal;


//using TriangleMeshType = metal::mesh<VertexOut, PrimOut, MaxVertexCount, MaxPrimitiveCount, topology::triangle>;



struct Vertex {
    float3 position;
    float3 normal;
    // Constructor
        Vertex() {}
        Vertex(float3 pos, float3 norm) {
            position = pos;
            normal = norm;
        }
};

struct VertexOut
{
    float4 position [[position]];
    float3 normal;
    
};


// Per-vertex primitive data.
struct PrimeOut
{
    float4 color;
};

struct fragmentIn
{
    VertexOut v;
    PrimeOut p;
};



struct InstanceConstants {
    float4x4 modelMatrix;
    float4x4 normalMatrix;
    float4 color;
};

//
//static constexpr constant uint32_t MaxVertexCount = 24;
//static constexpr constant uint32_t MaxPrimitiveCount = 24;
//using TriangleMeshType = metal::mesh<VertexOut, PrimeOut, MaxVertexCount, MaxPrimitiveCount, metal::topology::triangle>;
//
// Define cube vertices and indices globally
//constant float3 meshVertices[8] = {
//    float3(-1, -1, -1), float3(1, -1, -1),
//    float3(-1,  1, -1), float3(1,  1, -1),
//    float3(-1, -1,  1), float3(1, -1,  1),
//    float3(-1,  1,  1), float3(1,  1,  1)
// };
//constant uint meshIndices[36] = {
//    0, 1, 2, 2, 1, 3,    // Front face
//    1, 5, 3, 3, 5, 7,    // Right face
//    5, 4, 7, 7, 4, 6,    // Back face
//    4, 0, 6, 6, 0, 2,    // Left face
//    2, 3, 6, 6, 3, 7,    // Top face
//    4, 5, 0, 0, 5, 1     // Bottom face
//};
//
//constant uint meshVerticesCount = 8;
//constant uint meshIndicesCount = 36;

constant int stackCount = 10;
constant int sectorCount = 10;
constant float PI = 3.14159265358979323846;

static constexpr constant uint32_t MaxVertexCount = (stackCount + 1) * (sectorCount + 1);
static constexpr constant uint32_t MaxPrimitiveCount = stackCount * sectorCount * 2;
using TriangleMeshType = metal::mesh<VertexOut, PrimeOut, MaxVertexCount, MaxPrimitiveCount, topology::triangle>;



struct MeshPayload {
    Vertex vertices[MaxVertexCount];
    float4x4 transform;
    float4x4 normalMatrix;
    float4 color;
    uint32_t primitiveCount;
    uint32_t vertexCount;
};


[[object]]
void objectStage(object_data MeshPayload& payload [[payload]],
                 constant InstanceConstants* instance [[buffer(1)]],
                 constant float4x4 &viewProjectionMatrix [[buffer(2)]],
                 mesh_grid_properties props,
                 uint3 positionInGrid [[threadgroup_position_in_grid]]){
    uint threadIndex = positionInGrid.x;
    // Initialize payload with instance-specific data
    payload.transform = viewProjectionMatrix * instance[threadIndex].modelMatrix;
    payload.normalMatrix = instance[threadIndex].normalMatrix;
    payload.color = instance[threadIndex].color;
    
    payload.vertexCount = MaxVertexCount;
    payload.primitiveCount = MaxPrimitiveCount;
    // Initialize vertices
    float stackStep = PI / stackCount;
        float sectorStep = 2 * PI / sectorCount;
        float radius = 1.0;
        float xy, z;
        uint index = 0;
    for (int i = 0; i <= stackCount; ++i) {
            float stackAngle = PI / 2 - i * stackStep;        // starting from pi/2 to -pi/2
            xy = radius * cos(stackAngle);             // r * cos(u)
            z = radius * sin(stackAngle);              // r * sin(u)

            // add (sectorCount+1) vertices per stack
            for (int j = 0; j <= sectorCount; ++j) {
                float sectorAngle = j * sectorStep;           // starting from 0 to 2pi
                // vertex position (x, y, z)
                float x = xy * cos(sectorAngle);             // r * cos(u) * cos(v)
                float y = xy * sin(sectorAngle);             // r * cos(u) * sin(v)
                payload.vertices[index++] = Vertex(float3(x, y, z), normalize(float3(x, y, z))); 
            }
        }
    // Set the threadgroups per grid
    props.set_threadgroups_per_grid(uint3(1, 1, 1));
    
}

[[mesh]]
void meshStage(TriangleMeshType output,
               const object_data MeshPayload& payload [[payload]],
               uint lid [[thread_index_in_threadgroup]],
               uint tid [[threadgroup_position_in_grid]]){
    if (lid == 0)
    {
        output.set_primitive_count(payload.primitiveCount);
        int k1, k2;
                uint index = 0;
                for (int i = 0; i < stackCount; ++i) {
                    k1 = i * (sectorCount + 1);     // beginning of current stack
                    k2 = k1 + sectorCount + 1;      // beginning of next stack

                    for (int j = 0; j < sectorCount; ++j, ++k1, ++k2) {
                        // 2 triangles per sector excluding first and last stacks
                        if (i != 0) {
                            output.set_index(index++, k1);
                            output.set_index(index++, k2);
                            output.set_index(index++, k1 + 1);
                        }

                        if (i != (stackCount - 1)) {
                            output.set_index(index++, k1 + 1);
                            output.set_index(index++, k2);
                            output.set_index(index++, k2 + 1);
                        }
                    }
                }
    }
    if (lid < payload.vertexCount) {
        VertexOut v;
        float4 position = float4(payload.vertices[lid].position, 1.0);
        v.position = payload.transform * position;
        v.normal = (payload.normalMatrix * float4(payload.vertices[lid].normal, 0.0)).xyz;
        output.set_vertex(lid, v);
    }
    
    if (lid < payload.primitiveCount) {
        PrimeOut p;
        p.color = payload.color;
        output.set_primitive(lid, p);
    }
    
    
}

fragment float4 fragmShader(fragmentIn in [[stage_in]])
{
    float3 N = normalize(in.v.normal);
    float3 L = float3(1,1,1);
    float NdotL = 0.75 + 0.25*dot(N, L);
    return float4(mix(in.p.color.xyz * NdotL, N*0.5+0.5, 0.2), 1.0f);
}
