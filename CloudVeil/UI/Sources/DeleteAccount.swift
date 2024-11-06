import Foundation
import UIKit

import TelegramPresentationData

import CloudVeilSecurityManager

public final class CVDeleteAccount : UIViewController, CVWrappedViewController, UITextFieldDelegate {
	private let uiStyle: UIUserInterfaceStyle
	private let bgColor: UIColor
	private let textColor: UIColor
	private let borderColor: UIColor
	private let btnColor: UIColor
	private let btnDisabledColor: UIColor
	private let btnTextColor: UIColor

	private var canDelete = false

	public let presentationData: PresentationData
	public let needsNavBar = true

	private let tgUserID: Int64
	private let onSucceed: () -> Void
	private let onFail: () -> Void

	public init(_ tgUserID: Int64, _ presentData: PresentationData, onSucceed: @escaping () -> Void = {}, onFail: @escaping () -> Void = {}) {
		let theme = presentData.theme
		self.presentationData = presentData
		self.tgUserID = tgUserID
		self.onSucceed = onSucceed
		self.onFail = onFail

		self.bgColor = theme.list.blocksBackgroundColor
		self.textColor = theme.list.itemPrimaryTextColor
		self.borderColor = theme.list.itemPlainSeparatorColor
		if theme.overallDarkAppearance {
			self.uiStyle = .dark
			self.btnColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 1)
			self.btnDisabledColor = .darkGray
			self.btnTextColor = .white
		} else {
			self.uiStyle = .light
			self.btnColor = .red
			self.btnDisabledColor = .lightGray
			self.btnTextColor = .black
		}

		super.init(nibName: nil, bundle: nil)
		self.title = "Delete CloudVeil Account"
	}

	required public init(coder: NSCoder) {
        fatalError("doesn't support Interface Builder: init(coder:) not implemented")
	}

	@objc func onDeletePressed() {
		if canDelete {
			let onSucceed = self.onSucceed
			let myOnSucceed = { [weak self] in
				DispatchQueue.main.async {
					let _ = self?.navigationController?.popViewController(animated: true)
				}
				onSucceed()
			}
			let onFail = self.onFail
			let myOnFail = { [weak self] in
				DispatchQueue.main.async {
					let _ = self?.navigationController?.popViewController(animated: true)
				}
				onFail()
			}
			CloudVeilSecurityController.shared.deleteAccount(tgUserID, onSucceed: myOnSucceed, onFail: myOnFail)
		}
	}

	private var deleteBtn: UIButton? = nil
	private var entry: MyTextField?  = nil

	@objc private func updateBtn() {
		self.canDelete = entry?.text == "DELETE"
		deleteBtn?.backgroundColor = canDelete ? self.btnColor : self.btnDisabledColor
		deleteBtn?.isEnabled = canDelete
	}

	override public func loadView() {
		let gaps = 16.0
		let btnHeight = 48.0
		let btnXPad = 48.0
		let zeroFrame = CGRect(x: 0, y: 0, width: 0, height: 0)

		let titleText = "Delete CloudVeil Account"
		let descText = "Permanently delete your CloudVeil account. This cannot be undone. Your Telegram account won't be deleted. To proceed, input DELETE below."
		let placeholder = "Input DELETE here"

		let titleView = UILabel()
		titleView.accessibilityIdentifier = "titleView"
		titleView.text = titleText
		titleView.textAlignment = .center
		titleView.font = .systemFont(ofSize: 21)
		titleView.textColor = self.textColor
		titleView.numberOfLines = 1

		let descView = UITextView(frame: zeroFrame, textContainer: nil)
		descView.accessibilityIdentifier = "descView"
		descView.text = descText
		descView.textColor = self.textColor
		descView.isSelectable = false
		descView.isScrollEnabled = false
		descView.backgroundColor = self.bgColor

		let entry = MyTextField()
		entry.accessibilityIdentifier = "entry"
		entry.placeholder = placeholder
		entry.returnKeyType = .done
		entry.keyboardType = .asciiCapable
		entry.textAlignment = .center
		entry.addTarget(self, action: #selector(Self.updateBtn), for: .allEditingEvents)
		entry.addTarget(entry, action: #selector(UITextField.resignFirstResponder), for: .editingDidEnd)
		entry.layer.borderColor = self.borderColor.cgColor
		entry.layer.borderWidth = 1
		self.entry = entry

		let stackView = UIStackView(arrangedSubviews: [titleView, descView, entry])
		stackView.accessibilityIdentifier = "stackView"
		stackView.axis = .vertical
		stackView.alignment = .center
		stackView.spacing = gaps

		let deleteBtn = UIButton(type: .custom)
		deleteBtn.accessibilityIdentifier = "deleteBtn"
		deleteBtn.setTitle("Delete Account", for: .normal)
		deleteBtn.setTitleColor(self.btnTextColor, for: .normal)
		deleteBtn.layer.cornerRadius = gaps
		if #available(iOS 14.0, *) {
			deleteBtn.role = .destructive
		}
		deleteBtn.addTarget(self, action: #selector(Self.onDeletePressed), for: .touchUpInside)
		self.deleteBtn = deleteBtn
		updateBtn()

		view = UIView()
		view.accessibilityIdentifier = "view"
		view.backgroundColor = self.bgColor
		view.addSubview(stackView)
		view.addSubview(deleteBtn)

		for x in [titleView, descView, entry, stackView, deleteBtn] {
			x.translatesAutoresizingMaskIntoConstraints = false
		}

		let visible: UILayoutGuide
		if #available(iOS 15.0, *) {
			visible = UILayoutGuide()
			view.addLayoutGuide(visible)

			visible.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor).isActive = true
			visible.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor).isActive = true
			visible.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
			visible.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor).isActive = true
		} else {
			visible = view.safeAreaLayoutGuide
		}

		titleView.setContentHuggingPriority(.required, for: .horizontal)
		descView.widthAnchor.constraint(equalTo: titleView.widthAnchor, multiplier: 1.2).isActive = true

		stackView.centerXAnchor.constraint(equalTo: visible.centerXAnchor).isActive = true
		let stackCenter = stackView.centerYAnchor.constraint(equalTo: visible.centerYAnchor)
		stackCenter.priority = .defaultHigh
		stackCenter.isActive = true
		stackView.bottomAnchor.constraint(lessThanOrEqualTo: visible.bottomAnchor, constant: -gaps).isActive = true

		deleteBtn.heightAnchor.constraint(equalToConstant: btnHeight).isActive = true
		let deleteBtnDefaultWidth = deleteBtn.widthAnchor.constraint(
			equalTo: deleteBtn.titleLabel!.widthAnchor, multiplier: 1, constant: btnXPad)
		deleteBtnDefaultWidth.priority = .defaultLow + 50
		deleteBtnDefaultWidth.isActive = true
		deleteBtn.widthAnchor.constraint(
			lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor,
			multiplier: 1, constant: -(gaps * 2)).isActive = true
		deleteBtn.bottomAnchor.constraint(
			equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -gaps).isActive = true
		deleteBtn.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
	}
}

