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
    float4x4 transform;
    float4x4 normalMatrix;
    float4 color;
    float3 cameraPosition;
    int lodLevel;
};




[[object]]
void objectStage(object_data MeshPayload& payload [[payload]],
                 constant InstanceConstants* instance [[buffer(1)]],
                 constant float4x4 &viewProjectionMatrix [[buffer(2)]],
                 constant float3 &cameraPosition [[buffer(3)]],
                 mesh_grid_properties props,
                 uint index [[thread_position_in_grid]]){
    uint threadIndex = index;
    // Initialize payload with instance-specific data
    payload.transform = viewProjectionMatrix * instance[threadIndex].modelMatrix;
    payload.normalMatrix = instance[threadIndex].normalMatrix;
    payload.color = instance[threadIndex].color;
    
    // Set the threadgroups per grid
    props.set_threadgroups_per_grid(uint3(1, 1, 1));
    
}

[[mesh]]
void meshStage(TriangleMeshType output,
               const object_data MeshPayload& payload [[payload]],
               uint lid [[thread_index_in_threadgroup]],
               uint tid [[threadgroup_position_in_grid]]){
    // Set primitive count
        if (lid == 0) {
            output.set_primitive_count(MaxPrimitiveCount);
        }
        
        // Generate vertices
        if (lid < MaxVertexCount) {
            int stack = lid / (sectorCount + 1);
            int sector = lid % (sectorCount + 1);
            
            float stackAngle = PI / 2 - stack * (PI / stackCount);
            float sectorAngle = sector * (2 * PI / sectorCount);
            
            float xy = cos(stackAngle);
            float z = sin(stackAngle);
            
            float x = xy * cos(sectorAngle);
            float y = xy * sin(sectorAngle);
            
            float3 position = float3(x, y, z);
            float3 normal = normalize(position);
            
            VertexOut v;
            v.position = payload.transform * float4(position, 1.0);
            v.normal = (payload.normalMatrix * float4(normal, 0.0)).xyz;
            output.set_vertex(lid, v);
        }
    // Generate indices
        if (lid < MaxPrimitiveCount) {
            int primitive = lid;
            int stack = primitive / (sectorCount * 2);
            int sector = (primitive % (sectorCount * 2)) / 2;
            int triIndex = primitive % 2;
            
            int k1 = stack * (sectorCount + 1) + sector;
            int k2 = k1 + sectorCount + 1;
            
            uint3 indices;
            if (triIndex == 0) {
                indices = uint3(k1, k2, k1 + 1);
            } else {
                indices = uint3(k1 + 1, k2, k2 + 1);
            }
            
            output.set_index(primitive * 3, indices.x);
            output.set_index(primitive * 3 + 1, indices.y);
            output.set_index(primitive * 3 + 2, indices.z);
            
            PrimeOut p;
            p.color = payload.color;
            output.set_primitive(primitive, p);
        }
    
    
}

fragment float4 fragmShader(fragmentIn in [[stage_in]])
{
    float3 N = normalize(in.v.normal);
    float3 L = float3(1,1,1);
    float NdotL = 0.75 + 0.25*dot(N, L);
    return float4(mix(in.p.color.xyz * NdotL, N*0.5+0.5, 0.2), 1.0f);
}
