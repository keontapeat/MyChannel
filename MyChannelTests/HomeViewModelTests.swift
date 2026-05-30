import XCTest
@testable import MyChannel

@MainActor
final class HomeViewModelTests: XCTestCase {
    
    var viewModel: HomeViewModel!

    override func setUp() {
        super.setUp()
        viewModel = HomeViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    func testInitialState() {
        // Assert
        XCTAssertFalse(viewModel.miniActive)
        XCTAssertEqual(viewModel.scrollOffset, 0)
        XCTAssertFalse(viewModel.isRefreshing)
        
        XCTAssertNil(viewModel.route)
        XCTAssertFalse(viewModel.showingQuickProfile)
        XCTAssertFalse(viewModel.showingSettings)
        XCTAssertFalse(viewModel.showingSwitchProfile)
        XCTAssertFalse(viewModel.showingFeaturedManager)
        
        XCTAssertTrue(viewModel.featuredContent.isEmpty)
        XCTAssertEqual(viewModel.heroVideoIndex, 0)
        
        XCTAssertTrue(viewModel.showingStories)
        XCTAssertTrue(viewModel.assetStories.isEmpty)
        XCTAssertTrue(viewModel.allAssetStories.isEmpty)
        XCTAssertFalse(viewModel.presentStoryCreator)
        
        XCTAssertEqual(viewModel.selectedHomeChip, .all)
    }
    
    func testFilterChipChange() {
        // Act
        viewModel.selectedHomeChip = .music
        
        // Assert
        XCTAssertEqual(viewModel.selectedHomeChip, .music)
    }
}
