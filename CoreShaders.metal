//
//  CoreShaders.metal
//  RayTracing
//
//  Created by Dmitri Wamback on 2023-06-05.
//

#include <metal_stdlib>
using namespace metal;


struct vertexin {
    packed_float3 _vertex;
};

struct vertexout {
    float4 fragp [[position]];
    float4 col;
    float2 uv;
};

struct uniforms {
    float2 windowScale;
};

vertex vertexout vMain(const device vertexin* vArray [[buffer(0)]], unsigned int id [[vertex_id]]) {
    
    vertexin i = vArray[id];
    vertexout o;
    
    o.fragp = float4(i._vertex, 1.0);
    o.col   = float4(1.0);
    o.uv    = (i._vertex.xy + float2(1)) / float2(2);
    
    return o;
}

// [-b +- sqrt(a^2 - 4ac)]/2a


float3 computeDiscriminant(float radius, float2 uv, float3 origin, float3 rayDirection) {
    
    float a = dot(rayDirection, rayDirection);
    float b = 2 * dot(origin, rayDirection);
    float c = dot(origin, origin) - pow(radius, 2);
    
    float discriminant = pow(b, 2) - (4 * a * c);
    if (discriminant >= 0) {
        float closestIntersection = (-b - sqrt(discriminant)) / (2*a);
        float furthestIntersection = (-b + sqrt(discriminant)) / (2*a);
        
        return float3(discriminant, furthestIntersection, closestIntersection);
    }
    return float3(-1, 0, 0);
}


kernel void cMain(texture2d<half, access::read_write> texture [[texture(0)]], constant uniforms &u [[buffer(1)]], uint2 index [[thread_position_in_grid]]) {
    
    float2 uv = float2(index.x / u.windowScale.x - 0.5, index.y / u.windowScale.y - 0.5);
    float3 origin = float3(0.0, 0.0, -3.0);
    float3 rayDirection = float3(uv, -1.0);
    
    float3 discriminants = computeDiscriminant(1.0, uv, origin, rayDirection);
    
    if (discriminants.x != -1) {
        
        float closest = discriminants.z;
        float furthest = discriminants.y;
        float3 closestHit = origin + rayDirection * closest;
        float3 normal = -closestHit;
        
        texture.write(half4(half3(normal), 1.0), index);
    }
    else {
        texture.write(half4(0.0), index);
    }
}

fragment float4 fMain(vertexout i [[stage_in]], texture2d<float> texture [[texture(0)]]) {
    
    constexpr sampler sample = sampler(coord::normalized, address::clamp_to_zero, filter::nearest);
    float4 fragc = texture.sample(sample, float2(i.uv.x, i.uv.y));
    
    return fragc;
}
