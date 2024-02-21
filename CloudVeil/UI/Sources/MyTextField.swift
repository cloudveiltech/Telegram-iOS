import Foundation
import UIKit

// subclass because UIKit is deficient
public class MyTextField: UITextField {
	private let padding = 4.0
	private var editingInsets: UIEdgeInsets
	private var textInsets: UIEdgeInsets

	public init() {
		editingInsets = UIEdgeInsets(top: padding, left: 0, bottom: padding, right: 0)
		textInsets = editingInsets
		super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
	}

	required public init?(coder: NSCoder) {
		editingInsets = UIEdgeInsets(top: padding, left: 0, bottom: padding, right: 0)
		textInsets = editingInsets
		super.init(coder: coder)
	}

	override public func didMoveToSuperview() {
		super.didMoveToSuperview()
		sizeToFit()
		textInsets.left = layer.bounds.height / 2
		textInsets.right = textInsets.left
		layer.cornerRadius = textInsets.left
		sizeToFit()
	}

	override public func textRect(forBounds bounds: CGRect) -> CGRect {
		return bounds.inset(by: self.textInsets)
	}

	override public func editingRect(forBounds bounds: CGRect) -> CGRect {
		return bounds.inset(by: self.editingInsets)
	}
}
