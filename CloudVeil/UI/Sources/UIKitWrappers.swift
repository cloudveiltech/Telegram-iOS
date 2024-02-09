import Foundation
import UIKit

import AsyncDisplayKit
import Display
import TelegramPresentationData

private final class CVVWrapper<C> : ASDisplayNode where C: UIViewController, C: CVWrappedViewController {
	let wrapped: C
	let wrapping: CVVCWrapper<C>

	init(_ wrapped: C, _ wrapping: CVVCWrapper<C>) {
		self.wrapped = wrapped
		self.wrapping = wrapping
		super.init()
	}

	public override func didLoad() {
		super.didLoad()
		self.wrapping.addChild(wrapped)
		self.wrapped.view.frame = self.bounds
		self.view.addSubview(self.wrapped.view)
		self.wrapped.didMove(toParent: self.wrapped)
	}

	public override func layout() {
		super.layout()
		self.wrapped.view.frame = self.bounds
	}
}

public protocol CVWrappedViewController {
	var statusBarStyle: PresentationThemeStatusBarStyle { get }
}

// Wraps the Telegram stupidity around a standard UIKit UIViewController.
public final class CVVCWrapper<C> : ViewController where C: UIViewController, C: CVWrappedViewController {
	var wrapped: C
	public init(_ wrapped: C, _ presentationData: NavigationBarPresentationData? = nil) {
		self.wrapped = wrapped
		super.init(navigationBarPresentationData: presentationData)
		self.statusBar.statusBarStyle = wrapped.statusBarStyle.style
	}

	required public init(coder: NSCoder) {
        fatalError("doesn't support Interface Builder: init(coder:) not implemented")
    }

	override public func loadDisplayNode() {
		self.displayNode = CVVWrapper(self.wrapped, self)
	}
}
