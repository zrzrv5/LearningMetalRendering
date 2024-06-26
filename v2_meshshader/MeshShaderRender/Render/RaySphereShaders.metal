//
//  RaySphereShaders.metal
//  MeshShaderRender
//
//  Created by Rui Zhou on 6/23/24.
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
    float radius;
    float4 color;
    float4 eyePos;
};

vertex VertexOut vertexShader(const device float3* spherePositions [[buffer(0)]],
                             const device float* sphereRadii [[buffer(1)]],
                             const device float4* sphereColors [[buffer(2)]],
                             constant float4x4& viewMat [[buffer(3)]],
                              constant float4x4& projMat [[buffer(4)]],
                             uint vertexID [[vertex_id]],
                              uint instanceID [[instance_id]]) {
    VertexOut out;
    
    float3 worldPos = spherePositions[instanceID];
    float radius = sphereRadii[instanceID];
    float4 color = sphereColors[instanceID];
    
    // calculate billboard corners
    float2 corner = float2((vertexID & 1)? 1: -1, (vertexID & 2)? -1:1);
    
    // Transform sphere center to view space
    float4 viewPos = viewMat * float4(worldPos, 1.0);
    
    //Apply offset in viewspace
    viewPos.xy += corner * radius;
    
    // project to clip space
    float4 clipPos = projMat * viewPos;
    
    
    out.position = clipPos;
    out.worldPos = worldPos;
    out.radius = radius;
    out.color = color;
    out.eyePos = viewPos;
    
    return out;
}



// Helper function to calculate the ray-sphere intersection
float raySphereIntersection(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius) {
    float3 oc = rayOrigin - sphereCenter;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float h = b * b - c;
    if (h < 0.0) return -1.0;
    h = sqrt(h);
    float t = -b - h;
    return (t < 0.0) ? -b + h : t;
}

// Helper function to calculate the normal at the hit point
float3 calculateNormal(float3 hitPoint, float3 sphereCenter) {
    return normalize(hitPoint - sphereCenter);
}

struct FragmentOut {
    float4 color [[color(0)]];
    float depth [[depth(any)]];
};
constant float specular_strength = 0.25;
constant float shininess = 6.0;
constant float3 specular_lightdir = normalize(float3(1.8, 1.5, 0.2));
constant float ambient = 0.4;
constant float diffuse_strength = 1.0 - ambient;

float4 outputShadedRay(float4 color, float3 surface_normal, float3 ray_dir) {
    float specular = pow(max(0.0, dot(reflect(specular_lightdir, surface_normal), ray_dir)), shininess) * specular_strength;
    float diffuse = abs(surface_normal.z) * diffuse_strength;
    return float4(color.rgb * (diffuse + ambient) + float3(specular), color.a);
}



fragment FragmentOut fragmentShader(VertexOut in [[stage_in]],
                              constant float3& cameraPos [[buffer(1)]],
                              constant float2& viewportSize [[buffer(2)]],
                              constant float4x4& invProjMat [[buffer(3)]],
                              float2 point_coord [[point_coord]]
                              ) {
    // Calculate the normalized device coordinates (NDC)
    float2 ndc = (in.position.xy / viewportSize) * 2.0 - 1.0;
    
    // Transform NDC to view space using the inverse projection matrix
        float4 ndcPos = float4(ndc.x, -ndc.y, 1.0, 1.0);
        float4 viewPos = invProjMat * ndcPos;
        viewPos /= viewPos.w;
    // Calculate the ray dir
    float3 rayDir = normalize(viewPos.xyz - cameraPos);

    
    
    // Perform the ray-sphere intersection test
    float t = raySphereIntersection(cameraPos, rayDir, in.worldPos, in.radius);
    
    if (t < 0.0) {
//        discard_fragment();
    }
    
    // Calculate the hit point and the normal
    float3 hitPoint = cameraPos + rayDir * t;
    float3 normal = calculateNormal(hitPoint, in.worldPos);
    
    // Simple lighting calculation
    float3 lightDir = normalize(float3(-1.0, -1.0, 1.5));
    float diffuse = max(dot(normal, lightDir), 0.0);
    float3 ambient = float3(0.1, 0.1, 0.1);
    float3 finalColor = ambient + diffuse * in.color.rgb;
    
    float4 projectedIntersection = invProjMat * float4(hitPoint, 1.0);
    float zdepth = (projectedIntersection.z / projectedIntersection.w + 1.0) * 0.5;
    
    FragmentOut out;
//    out.color = outputShadedRay(<#float4 color#>, <#float3 surface_normal#>, <#float3 ray_dir#>)
    out.color = float4(finalColor, in.color.a);
    out.depth = zdepth;
    
    return out;
    
//    return float4(finalColor, in.color.a);
}




/*


float raySphere(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius) {
    float3 oc = rayOrigin - sphereCenter;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float h = b * b - c;
    if (h < 0.0) return -1.0;
    h = sqrt(h);
    float t = -b - h;
    return (t < 0.0) ? -b + h : t;
}

float3 calculateNormal(float3 hitPoint, float3 sphereCenter) {
    return normalize(hitPoint - sphereCenter);
}

float4 shadeSurfaceColorDir(float3 normal, float4 color, float3 lightDir) {
    float3 ambientLight = float3(0.3, 0.3, 0.3);
    float3 lightColor = float3(1.0, 1.0, 1.0);
       float diffuse = max(dot(normal, lightDir), 0.0);
    float3 finalColor = ambientLight + diffuse * lightColor * color.rgb;
       return float4(finalColor, color.a);
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant float3& cameraPos [[buffer(1)]],
                               constant float2& viewportSize [[buffer(2)]],
                               constant float4x4& projection_matrix [[buffer(3)]],
                               float2 point_coord [[point_coord]]
                               ) {
    float2 ndc = (in.position.xy / viewportSize) * 2.0 - 1.0;
        float3 rayDir = normalize(float3(ndc.x, -ndc.y, 1.0));
        
        float t = raySphere(cameraPos, rayDir, in.worldPos, in.radius);
        
        if (t < 0.0) {
            discard_fragment();
        }
        
        float3 hitPoint = cameraPos + rayDir * t;
        float3 normal = calculateNormal(hitPoint, in.worldPos);
        
        // Simple lighting
        float3 lightDir = normalize(float3(-1.0, -1.0, 1.5));
        float diffuse = max(dot(normal, lightDir), 0.0);
        float3 ambient = float3(0.1);
        float3 finalColor = ambient + diffuse * in.color.rgb;
        
        return float4(finalColor, in.color.a);

}

//fragment float4 fragmentShader(VertexOut in [[stage_in]],
//                               constant float3& cameraPosition [[buffer(1)]],
//                               constant float2& viewportSize [[buffer(2)]]) {
//    // Calculate ray direction in view space
//        float3 rayOrigin = cameraPosition;
//        float3 rayDir = normalize(in.worldPos - rayOrigin);
//        
//        // Ray-sphere intersection in view space
//        float3 oc = rayOrigin - in.worldPos;
//        float b = dot(rayDir, oc);
//        float c = dot(oc, oc) - (in.radius * in.radius);
//        float discriminant = b * b - c;
//        
//        if (discriminant < 0.0) {
//            discard_fragment();
//        }
//        
//        float t = -b - sqrt(discriminant);
//        if (t < 0.0) {
//            discard_fragment();
//        }
//        
//        float3 hitPoint = rayOrigin + rayDir * t;
//        float3 normal = normalize(hitPoint - in.worldPos);
//        
//        // Simple lighting
//        float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
//        float diffuse = max(dot(normal, lightDir), 0.0);
//        float3 ambient = float3(0.1, 0.1, 0.1);
//        float3 finalColor = ambient + diffuse * in.color.rgb;
//        
//        return float4(finalColor, in.color.a);
//}

//fragment float4 fragmentShader(VertexOut in [[stage_in]],
//                               constant float3& cameraPosition [[buffer(1)]]) {
//    // Calculate ray direction in world space
//    float3 rayOrigin = cameraPosition;
//    float3 rayDir = normalize(in.worldPos - rayOrigin);
//    
//    // Ray-sphere intersection
//    float3 sphereCenter = in.worldPos;
//    float sphereRadius = in.radius;
//    float3 oc = rayOrigin - sphereCenter;
//    float b = dot(rayDir, oc);
//    float c = dot(oc, oc) - sphereRadius * sphereRadius;
//    float discriminant = b * b - c;
//    
//    if (discriminant < 0.0) {
//        discard_fragment();
//    }
//    
//    float t = -b - sqrt(discriminant);
//    if (t < 0.0) {
//        discard_fragment();
//    }
//    
//    // Calculate hit point and normal
//    float3 hitPoint = rayOrigin + rayDir * t;
//    float3 normal = normalize(hitPoint - sphereCenter);
//    
//    // Simple lighting
//    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
//    float diffuse = max(dot(normal, lightDir), 0.0);
//    float3 ambient = float3(0.1);
//    float3 finalColor = ambient + diffuse * in.color.rgb;
//    
//    // Add some specular highlight
//    float3 viewDir = normalize(rayOrigin - hitPoint);
//    float3 reflectDir = reflect(-lightDir, normal);
//    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
//    float3 specular = float3(0.5) * spec;
//    
//    finalColor += specular;
//    
//    return float4(finalColor, in.color.a);
//}
*/
