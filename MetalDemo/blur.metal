
#include <metal_stdlib>
#include "Utils.h"
#include "MetalTextureIDs.h"

using namespace metal;

kernel void blur3x3Kernel(texture2d<float, access::read> input [[ texture(kBlur3x3InputTexture) ]] ,
                          texture2d<float, access::write> output [[ texture(kBlur3x3OutputTexture) ]],
                          uint2 pos [[ thread_position_in_grid ]])
{
  if (! isInsideTexture(pos, output))
    return;
  
  if (pos.x == 0 && pos.y == 0)
  {
    output.write(float4(1.0, 0.0, 0.0, 1.0), pos);
    return;
  }
  
  if (isWithinBorder(pos, output, 1))
  {
    output.write(float4(0.0, 1.0, 1.0, 1.0), pos);
    return;
  }
  
  float3 kernelSum =
      input.read(uint2(pos.x-1, pos.y-1)).rgb
    + input.read(uint2(pos.x,   pos.y-1)).rgb
    + input.read(uint2(pos.x+1, pos.y-1)).rgb
    
    + input.read(uint2(pos.x-1, pos.y)).rgb
    + input.read(uint2(pos.x,   pos.y)).rgb
    + input.read(uint2(pos.x+1, pos.y)).rgb
    
    + input.read(uint2(pos.x-1, pos.y+1)).rgb
    + input.read(uint2(pos.x,   pos.y+1)).rgb
    + input.read(uint2(pos.x+1, pos.y+1)).rgb;
  
  float3 mean = kernelSum / 9;
  output.write(float4(mean.r, mean.g, mean.b, 1.0), pos);
}

