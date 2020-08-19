import XCTest
@testable import WooCommerce

final class TopBannerViewTests: XCTestCase {

    func test_it_hides_actionStackView_if_no_actionButtons_are_provided() throws {
        // Given
        let viewModel = createViewModel(with: [])
        let topBannerView = TopBannerView(viewModel: viewModel)

        // When
        let mirrorView = try mirror(of: topBannerView)

        // Then
        XCTAssertTrue(mirrorView.actionButtons.isEmpty)
        XCTAssertNil(mirrorView.actionStackView.superview)
    }

    func test_it_shows_actionStackView_if_actionButtons_are_provided() throws {
        // Given
        let actionButton = ActionButton(title: "Button", action: {})
        let actionButton2 = ActionButton(title: "Button2", action: {})
        let viewModel = createViewModel(with: [actionButton, actionButton2])
        let topBannerView = TopBannerView(viewModel: viewModel)

        // When
        let mirrorView = try mirror(of: topBannerView)

        // Then
        XCTAssertEqual(mirrorView.actionButtons.count, 2)
        XCTAssertNotNil(mirrorView.actionStackView.superview)
    }

    func test_it_forwards_actionButtons_actions_correctly() throws {
        // Given
        var actionInvoked = false
        let actionButton = ActionButton(title: "Button", action: {
            actionInvoked = true
        })
        let viewModel = createViewModel(with: [actionButton])
        let topBannerView = TopBannerView(viewModel: viewModel)

        // When
        let mirrorView = try mirror(of: topBannerView)
        mirrorView.actionButtons[0].sendActions(for: .touchUpInside)

        // Then
        XCTAssertTrue(actionInvoked)
    }
}

private extension TopBannerViewTests {
    func createViewModel(with actionButtons: [ActionButton]) -> TopBannerViewModel {
        TopBannerViewModel(title: "", infoText: "", icon: nil, isExpanded: true, topButton: .chevron(handler: nil), actionButtons: actionButtons)
    }
}


// MARK: - Mirroring

private extension TopBannerViewTests {
    struct TopBannerViewMirror {
        let actionStackView: UIStackView
        let actionButtons: [UIButton]
    }

    func mirror(of view: TopBannerView) throws -> TopBannerViewMirror {
        let mirror = Mirror(reflecting: view)
        return TopBannerViewMirror(
            actionStackView: try XCTUnwrap(mirror.descendant("actionStackView") as? UIStackView),
            actionButtons: try XCTUnwrap(mirror.descendant("actionButtons") as? [UIButton])
        )
    }
}
