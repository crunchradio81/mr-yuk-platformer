import SwiftUI
import SpriteKit

struct ContentView: View {
    private let scene: GameScene = {
        let scene = GameScene(size: CGSize(width: 640, height: 480))
        scene.scaleMode = .aspectFit
        return scene
    }()

    var body: some View {
        GameView(scene: scene)
            .background(Color.black)
            .frame(minWidth: 800, minHeight: 600)
    }
}

private struct GameView: NSViewRepresentable {
    let scene: SKScene

    func makeNSView(context: Context) -> SKView {
        let view = KeyboardSKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.showsFPS = false
        view.showsNodeCount = false
        view.presentScene(scene)
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: SKView, context: Context) {
        if nsView.scene !== scene {
            nsView.presentScene(scene)
        }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class KeyboardSKView: SKView {
    override var acceptsFirstResponder: Bool { true }
}
