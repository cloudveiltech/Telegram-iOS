
import Foundation

class Debouncer: NSObject {
    var callback: (() -> ())
    var delay: Double
    weak var timer: Timer?
    
    init(delay: Double, callback: @escaping (() -> ())) {
        self.delay = delay
        self.callback = callback
    }
    
    func call() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            let nextTimer = Timer.scheduledTimer(timeInterval: self.delay, target: self, selector: #selector(Debouncer.fireNow), userInfo: nil, repeats: false)
            self.timer = nextTimer
        }
    }
    
    @objc func fireNow() {
        self.callback()
    }
}
