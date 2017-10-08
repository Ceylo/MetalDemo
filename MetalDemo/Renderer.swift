
import Metal
import MetalKit
import Foundation
import MetalPerformanceShaders

func loadInputImage(device : MTLDevice, location : URL) -> MTLTexture
{
  let loader = MTKTextureLoader(device: device)
  let loadOptions : [MTKTextureLoader.Option : Any] = [
    MTKTextureLoader.Option.textureUsage : NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
    MTKTextureLoader.Option.origin : MTKTextureLoader.Origin.topLeft.rawValue,
    MTKTextureLoader.Option.SRGB : NSNumber(value: false)
    ]
  
  return (try? loader.newTexture(URL: location, options: loadOptions))!
}

class Renderer {
  
  var device : MTLDevice
  var commandQueue : MTLCommandQueue
  var inputTexture : MTLTexture
  var outputTexture : MTLTexture
  var workingTexture1 : MTLTexture
  var workingTexture2 : MTLTexture
  
  init(imageURL : URL, device : MTLDevice)
  {
    self.device = device
    
    inputTexture = loadInputImage(device: device, location: imageURL)

    let textureDescriptor = MTLTextureDescriptor()
    textureDescriptor.textureType = .type2D
    textureDescriptor.pixelFormat = .rgba8Unorm
    textureDescriptor.width = inputTexture.width
    textureDescriptor.height = inputTexture.height
    
    textureDescriptor.usage = [ .shaderWrite ]
    outputTexture = device.makeTexture(descriptor: textureDescriptor)!
    outputTexture.label = "Final Output"
    
    textureDescriptor.pixelFormat = .bgra8Unorm
    textureDescriptor.usage = [ .shaderRead, .shaderWrite ]
    textureDescriptor.storageMode = .private
    workingTexture1 = device.makeTexture(descriptor: textureDescriptor)!
    workingTexture1.label = "Working texture 1"
    workingTexture2 = device.makeTexture(descriptor: textureDescriptor)!
    workingTexture2.label = "Working texture 2"
    
    commandQueue = device.makeCommandQueue()!
  }

  func enqueueKernel(commandBuffer : MTLCommandBuffer,
                     input : MTLTexture,
                     output : MTLTexture)
  {
    assert(false, "Must be overriden by subclasses")
  }
  
  func render()
  {
    MTLCaptureManager.shared().startCapture(device: device)
    
    let allCommandsBuffer = commandQueue.makeCommandBuffer()!
    allCommandsBuffer.label = "CommandBuffer for a single correction Execute"
    
    enqueueKernel(commandBuffer: allCommandsBuffer, input: inputTexture, output: workingTexture1)
    enqueueKernel(commandBuffer: allCommandsBuffer, input: workingTexture1, output: workingTexture2)
    enqueueKernel(commandBuffer: allCommandsBuffer, input: workingTexture2, output: outputTexture)
    
    // Ask to fetch texture from GPU
    let blitEncoder = allCommandsBuffer.makeBlitCommandEncoder()!
    blitEncoder.label = "CPU/GPU sync"
    blitEncoder.synchronize(resource: outputTexture)
    blitEncoder.endEncoding()
    
    allCommandsBuffer.commit()
    allCommandsBuffer.waitUntilCompleted()
    
    MTLCaptureManager.shared().stopCapture()
    
    if let error = allCommandsBuffer.error {
      print("Metal error: \(error)")
    }
  }
}

class Custom_Renderer : Renderer
{
  var computePipelineState : MTLComputePipelineState
  
  override init(imageURL: URL, device: MTLDevice) {
    let defaultLib = device.makeDefaultLibrary()!
    let blurFunction = defaultLib.makeFunction(name: "blur3x3Kernel")!
    computePipelineState = (try? device.makeComputePipelineState(function: blurFunction))!
    
    super.init(imageURL: imageURL, device: device)
  }
  
  override func enqueueKernel(commandBuffer: MTLCommandBuffer, input: MTLTexture, output: MTLTexture)
  {
    let w = computePipelineState.threadExecutionWidth
    let h = computePipelineState.maxTotalThreadsPerThreadgroup / w
    
    let threadsPerThreadGroup = MTLSizeMake(w, h, 1)
    let threadGroupsPerGrid = MTLSize(width: (inputTexture.width + w - 1) / w,
                                      height: (inputTexture.height + h - 1) / h,
                                      depth: 1)
    
    let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
    computeEncoder.label = "3x3 blur kernel"
    computeEncoder.setComputePipelineState(computePipelineState)
    computeEncoder.setTexture(input, index: Int(kBlur3x3InputTexture.rawValue))
    computeEncoder.setTexture(output, index: Int(kBlur3x3OutputTexture.rawValue))
    computeEncoder.dispatchThreadgroups(threadGroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
    computeEncoder.endEncoding()
  }
}

class MetalPerformanceShaders_Renderer : Renderer
{
  var blurMPSFilter : MPSImageBox
  
  override init(imageURL : URL, device : MTLDevice)
  {
    blurMPSFilter = MPSImageBox(device: device, kernelWidth: 3, kernelHeight: 3)
    blurMPSFilter.edgeMode = .clamp
    print(blurMPSFilter.sourceRegion(destinationSize: MTLSizeMake(200, 300, 1)))
    super.init(imageURL: imageURL, device: device);
  }
  
  override func enqueueKernel(commandBuffer: MTLCommandBuffer, input: MTLTexture, output: MTLTexture)
  {
    blurMPSFilter.encode(commandBuffer: commandBuffer, sourceTexture: input, destinationTexture: output)
  }
}
