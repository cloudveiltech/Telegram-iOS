
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
        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.timer?.invalidate()
                let nextTimer = Timer.scheduledTimer(timeInterval: strongSelf.delay, target: strongSelf, selector: #selector(Debouncer.fireNow), userInfo: nil, repeats: false)
                strongSelf.timer = nextTimer
            }
        }
    }
    
    @objc func fireNow() {
        self.callback()
    }
}
