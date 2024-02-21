import Foundation
import UIKit

import AsyncDisplayKit
import Display
import TelegramPresentationData

private final class CVVWrapper<C> : ASDisplayNode where C: UIViewController {
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
	var presentationData: PresentationData { get }
	var needsNavBar: Bool { get }
}

// Wraps the Telegram stupidity around a standard UIKit UIViewController.
public final class CVVCWrapper<C> : ViewController where C: UIViewController {
	var wrapped: C
	public init(_ wrapped: C, showNavBar: Bool = true, presentationData: PresentationData) {
		self.wrapped = wrapped
		if showNavBar {
			super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
		} else {
			super.init(navigationBarPresentationData: nil)
		}
		self.title = wrapped.title

		self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
	}

	public convenience init(_ wrapped: C) where C: CVWrappedViewController {
		self.init(wrapped, showNavBar: wrapped.needsNavBar, presentationData: wrapped.presentationData)
	}

	required public init(coder: NSCoder) {
        fatalError("doesn't support Interface Builder: init(coder:) not implemented")
    }

	override public func loadDisplayNode() {
		self.displayNode = CVVWrapper(self.wrapped, self)
	}
}
