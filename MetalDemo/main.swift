
import Metal

let inputImageName = "8mpx"
let imgUrl = Bundle.main.url(forResource: inputImageName, withExtension: "jpg")!
let device = MTLCreateSystemDefaultDevice()!

let renderers = [
//  Custom_Renderer(imageURL: imgUrl, device: device),
  MetalPerformanceShaders_Renderer(imageURL: imgUrl, device: device)
]

for renderer in renderers {
  let renderStart = Date()
  renderer.render()
  let renderTimeMs = Date().timeIntervalSince(renderStart) * 1000
  
  let className = String(describing: type(of: renderer))
  print("[\(device.name) - \(className)] \(String(format: "%.01f", renderTimeMs))ms\t")
}
