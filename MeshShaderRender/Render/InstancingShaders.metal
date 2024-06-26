//
//  Shaders.metal
//  MeshShaderRender
//
//  Created by Rui Zhou on 6/22/24.
//


#include <metal_stdlib>
using namespace metal;


struct InstanceConstants {
    float4x4 modelMatrix;
    float4x4 normalMatrix;
    float4 color;
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float4 color;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant InstanceConstants *instances [[buffer(1)]],
                             constant float4x4 &viewProjectionMatrix [[buffer(2)]],
                             uint instanceID [[instance_id]])
{
    VertexOut out;

    float4 position(in.position, 1);
    float4 normal(in.normal, 0);
    
    InstanceConstants instance = instances[instanceID];
    
    out.position = viewProjectionMatrix * instance.modelMatrix * position;
    out.normal = normalize((instance.normalMatrix * normal).xyz);
    out.color = instance.color;
    
    return out;
}

fragment half4 fragment_main(VertexOut in [[stage_in]]){
    float3 L(1, 1, 1);
    float3 N = normalize(in.normal);
    float3 ambientIntensity = float3(10.0);
    float3 lightIntensity = float3(12.0);
    float3 colorIntensity = ambientIntensity + lightIntensity * (0.5 + 0.5 * dot(N, L));

    // Reduce the dynamic range by a simple tone-mapping operator.
    colorIntensity = colorIntensity / (1.0 + colorIntensity);

    // Change the range of the normal from [-1, 1] to [0, 1] to use it as a color.
    float4 normalColor = float4(N * 0.5 + 0.5,1.0);
    // Add a 20% mix of the normal color with the shaded meshlet color.
    return half4(mix(float4(colorIntensity,1.0)*in.color, normalColor, 0.2));

}
