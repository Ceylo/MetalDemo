
import Metal

let inputImageName = "8mpx"
let imgUrl = Bundle.main.url(forResource: inputImageName, withExtension: "jpg")!
let devices = MTLCopyAllDevices()

for device in devices {
  let renderers = [
    Custom_Renderer(imageURL: imgUrl, device: device),
    MetalPerformanceShaders_Renderer(imageURL: imgUrl, device: device)
  ]
  
  for renderer in renderers {
    for _ in 1...10 {
      let renderStart = Date()
      renderer.render()
      let renderTimeMs = Date().timeIntervalSince(renderStart) * 1000
      
      let className = String(describing: type(of: renderer))
      print("[\(device.name) - \(className)] \(String(format: "%.01f", renderTimeMs))ms\t")
    }
  }
}
