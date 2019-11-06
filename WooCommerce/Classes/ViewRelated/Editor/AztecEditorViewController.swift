import UIKit
import Aztec
import WordPressEditor

/// Aztec's Native Editor!
final class AztecEditorViewController: UIViewController, Editor {
    var onContentSave: OnContentSave?

    private let content: String

    private let aztecUIConfigurator = AztecUIConfigurator()

    /// The editor view.
    ///
    private(set) lazy var editorView: Aztec.EditorView = {

        let paragraphStyle = ParagraphStyle.default
        paragraphStyle.lineSpacing = 4

        let missingIcon = UIImage.errorStateImage

        let editorView = Aztec.EditorView(
            defaultFont: StyleManager.subheadlineFont,
            defaultHTMLFont: StyleManager.subheadlineFont,
            defaultParagraphStyle: paragraphStyle,
            defaultMissingImage: missingIcon)

        aztecUIConfigurator.configureEditorView(editorView,
                                                textViewDelegate: self,
                                                textViewAttachmentDelegate: textViewAttachmentDelegate)

        return editorView
    }()

    /// Aztec's Awesomeness
    ///
    private var richTextView: Aztec.TextView {
        return editorView.richTextView
    }

    /// Aztec's Raw HTML Editor
    ///
    private var htmlTextView: UITextView {
        return editorView.htmlTextView
    }

    /// Aztec's Text Placeholder
    ///
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("Start writing...", comment: "Aztec's Text Placeholder")
        label.textColor = StyleManager.wooGreyMid
        label.font = StyleManager.subheadlineFont
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private lazy var keyboardFrameObserver: KeyboardFrameObserver = {
        let keyboardFrameObserver = KeyboardFrameObserver(onKeyboardFrameUpdate: handleKeyboardFrameUpdate(keyboardFrame:))
        return keyboardFrameObserver
    }()

    private let textViewAttachmentDelegate: TextViewAttachmentDelegate

    required init(content: String?, textViewAttachmentDelegate: TextViewAttachmentDelegate = AztecTextViewAttachmentHandler()) {
        self.content = content ?? ""
        self.textViewAttachmentDelegate = textViewAttachmentDelegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        registerAttachmentImageProviders()

        configureNavigationBar()
        configureView()
        configureSubviews()

        aztecUIConfigurator.configureConstraints(editorView: editorView,
                                                 editorContainerView: view,
                                                 placeholderView: placeholderLabel)

        setHTML(content)

        refreshPlaceholderVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startListeningToNotifications()
    }
}

private extension AztecEditorViewController {
    func configureNavigationBar() {
        title = NSLocalizedString("Description", comment: "The navigation bar title of the Aztec editor screen.")
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveButtonTapped))
    }

    func configureView() {
        edgesForExtendedLayout = UIRectEdge()
        view.backgroundColor = StyleManager.wooWhite
    }

    func configureSubviews() {
        view.addSubview(richTextView)
        view.addSubview(htmlTextView)
        view.addSubview(placeholderLabel)
    }

    func registerAttachmentImageProviders() {
        let providers: [TextViewAttachmentImageProvider] = [
            SpecialTagAttachmentRenderer(),
            CommentAttachmentRenderer(font: StyleManager.subheadlineBoldFont),
            HTMLAttachmentRenderer(font: StyleManager.subheadlineBoldFont),
            GutenpackAttachmentRenderer()
        ]

        for provider in providers {
            richTextView.registerAttachmentImageProvider(provider)
        }
    }
}

private extension AztecEditorViewController {
    func setHTML(_ html: String) {
        editorView.setHTML(html)
    }

    func getHTML() -> String {
        return editorView.getHTML()
    }

    func refreshPlaceholderVisibility() {
        placeholderLabel.isHidden = richTextView.isHidden || !richTextView.text.isEmpty
    }
}

// MARK: Keyboard frame update handling
//
private extension AztecEditorViewController {
    func handleKeyboardFrameUpdate(keyboardFrame: CGRect) {
        let referenceView = editorView.activeView

        let contentInsets  = UIEdgeInsets(top: referenceView.contentInset.top,
                                          left: 0,
                                          bottom: view.frame.maxY - (keyboardFrame.minY + self.view.layoutMargins.bottom),
                                          right: 0)

        htmlTextView.contentInset = contentInsets
        richTextView.contentInset = contentInsets

        updateScrollInsets()
    }

    func updateScrollInsets() {
        let referenceView = editorView.activeView
        var scrollInsets = referenceView.contentInset
        var rightMargin = (view.frame.maxX - referenceView.frame.maxX)
        rightMargin -= view.safeAreaInsets.right
        scrollInsets.right = -rightMargin
        referenceView.scrollIndicatorInsets = scrollInsets
    }
}

// MARK: - Notifications
//
private extension AztecEditorViewController {
    func startListeningToNotifications() {
        keyboardFrameObserver.startObservingKeyboardFrame()
    }
}

// MARK: - Navigation actions
//
private extension AztecEditorViewController {
    @objc func saveButtonTapped() {
        let content = getHTML()
        onContentSave?(content)

        navigationController?.popViewController(animated: true)
    }
}

// MARK: - UITextViewDelegate methods
//
extension AztecEditorViewController: UITextViewDelegate {

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        refreshPlaceholderVisibility()
    }

    func textViewDidChange(_ textView: UITextView) {
        refreshPlaceholderVisibility()
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return true
    }
}
