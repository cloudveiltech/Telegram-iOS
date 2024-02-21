import Foundation
import UIKit

import TelegramPresentationData

fileprivate let zeroFrame = CGRect(x: 0, y: 0, width: 100, height: 100)

fileprivate func loadFile(name: String) -> NSAttributedString {
	let path = Bundle.main.url(forResource: name, withExtension: "rtf")
	guard let path = path, let data = try? Data(contentsOf: path) else {
		return NSAttributedString(string: "\(name).rtf not readable")
	}
	return (try? NSAttributedString(data: data, options: [
		.documentType: NSAttributedString.DocumentType.rtf,
	], documentAttributes: nil)) ?? NSAttributedString(string: "\(name).rtf bad format")
}

public func loadCloudVeilAgreements() -> [NSAttributedString] {
	return [
		loadFile(name: "cloudveil-eula"),
	]
}

public final class CVMustAccept : UIViewController, CVWrappedViewController {
	private let text: NSAttributedString
	private let hasAgreed: () -> Void

	private let bgColor: UIColor
	private let textColor: UIColor
	private let btnColor: UIColor
	private let btnTextColor: UIColor

	public let presentationData: PresentationData
	public let needsNavBar = false

	public init(agreement: NSAttributedString, presentationData: PresentationData, hasAgreed: @escaping () -> Void) {
		let theme = presentationData.theme
		self.presentationData = presentationData

		self.bgColor = theme.list.blocksBackgroundColor
		self.textColor = theme.list.itemPrimaryTextColor
		self.btnColor = theme.list.itemCheckColors.fillColor
		self.btnTextColor = theme.list.itemCheckColors.foregroundColor
		let text = NSMutableAttributedString(attributedString: agreement)
		text.removeAttribute(.foregroundColor, range: NSMakeRange(0, text.length))
		text.removeAttribute(.backgroundColor, range: NSMakeRange(0, text.length))
		self.text = text
		self.hasAgreed = hasAgreed
		super.init(nibName: nil, bundle: nil)
	}

	required public init(coder: NSCoder) {
        fatalError("doesn't support Interface Builder: init(coder:) not implemented")
    }

	@objc func onAgree() {
		self.hasAgreed()
	}

	override public func loadView() {
		let gaps = 16.0
		let btnHeight = 48.0
		let textWidth = text.size().width.rounded(.up)

		let textView = UITextView(frame: zeroFrame, textContainer: nil)
		textView.isEditable = false
		textView.attributedText = text
		textView.textColor = self.textColor
		textView.backgroundColor = self.bgColor

		let agreeBtn = UIButton(type: .custom)
		agreeBtn.setTitle("I Agree", for: .normal)
		agreeBtn.setTitleColor(self.btnTextColor, for: .normal)
		agreeBtn.backgroundColor = self.btnColor
		agreeBtn.layer.cornerRadius = gaps
		agreeBtn.heightAnchor.constraint(equalToConstant: btnHeight).isActive = true
		if #available(iOS 14.0, *) {
			agreeBtn.role = .primary
		}
		agreeBtn.addTarget(self, action: #selector(Self.onAgree), for: .touchUpInside)


		let stackView = UIStackView(arrangedSubviews: [textView, agreeBtn])
		stackView.backgroundColor = self.bgColor
		stackView.axis = .vertical
		stackView.alignment = .center
		stackView.distribution = .fill
		stackView.spacing = gaps

		view = UIView()
		view.backgroundColor = self.bgColor
		view.addSubview(stackView)

		textView.translatesAutoresizingMaskIntoConstraints = false
		let textViewDefaultWidth = textView.widthAnchor.constraint(equalToConstant: textWidth)
		textViewDefaultWidth.priority = .defaultHigh
		textViewDefaultWidth.isActive = true
		textView.widthAnchor.constraint(
			lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor,
			multiplier: 1, constant: -(gaps * 2)).isActive = true

		agreeBtn.translatesAutoresizingMaskIntoConstraints = false
		let agreeBtnDefaultWidth = agreeBtn.widthAnchor.constraint(
			equalTo: agreeBtn.titleLabel!.widthAnchor, multiplier: 4)
		agreeBtnDefaultWidth.priority = .defaultHigh
		agreeBtnDefaultWidth.isActive = true
		agreeBtn.widthAnchor.constraint(
			lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor,
			multiplier: 1, constant: -(gaps * 2)).isActive = true

		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.topAnchor.constraint(
			equalTo: view.safeAreaLayoutGuide.topAnchor,
			constant: gaps).isActive = true
		stackView.bottomAnchor.constraint(
			equalTo: view.safeAreaLayoutGuide.bottomAnchor,
			constant: -gaps).isActive = true
		stackView.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
		stackView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
	}
}
