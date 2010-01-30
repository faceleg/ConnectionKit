//
//  KTPage.h
//  Sandvox
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import "KT.h"

#import "KTAbstractPage.h"
#import "NSManagedObject+KTExtensions.h"


typedef enum {
	SVCollectionSortManually,   // default as of 2.0
    SVCollectionSortAlphabetically,
    SVCollectionSortByDateCreated,
	SVCollectionSortByDateModified,
    SVCollectionSortOrderUnspecified = -1,		// used internally
} SVCollectionSortOrder;


@class KTDesign;
@class KTArchivePage, KTAbstractIndex, KTMaster, SVPageTitle, SVBody, KTCodeInjection;


@interface KTPage : KTAbstractPage
{
  @private
    // these ivars are only set if the page is root
	BOOL myIsNewPage;		// accessor is in category
}

#pragma mark Awake
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary;


#pragma mark Title
@property(nonatomic, retain) SVPageTitle *titleBox;  // you can use inherited .title property for ease of use too
- (BOOL)canEditTitle;


#pragma mark Body
@property(nonatomic, retain, readonly) SVBody *body;


#pragma mark Properties
@property(nonatomic, retain) KTMaster *master;
@property(nonatomic, copy) NSNumber *showSidebar;


#pragma mark Paths
@property(nonatomic, copy) NSString *customPathExtension;


#pragma mark Debugging
- (NSString *)shortDescription;

@end


#pragma mark -


@interface KTPage (Accessors)

#pragma mark Comments
@property(nonatomic, copy) NSNumber *allowComments;


#pragma mark Title
@property(nonatomic) BOOL shouldUpdateFileNameWhenTitleChanges;


#pragma mark Timestamp

- (NSString *)timestamp;
- (NSString *)timestampWithStyle:(NSDateFormatterStyle)aStyle;
- (NSDate *)timestampDate;

@property(nonatomic, copy) NSNumber *includeTimestamp;

@property(nonatomic) KTTimestampType timestampType;
- (NSString *)timestampTypeLabel;   // not KVO-compliant yet, but could easily be


#pragma mark Keywords
@property(nonatomic, copy) NSArray *keywords;
- (NSString *)keywordsList;

@end


#pragma mark -


@interface KTPage (Children)

#pragma mark Children
@property(nonatomic, copy, readonly) NSSet *childItems;
- (void)addChildItem:(SVSiteItem *)page;
- (void)removeChildItem:(SVSiteItem *)page;
- (void)removePages:(NSSet *)pages;


#pragma mark Sorting Properties

@property(nonatomic, copy) NSNumber *collectionSortOrder;  // SVCollectionSortOrder or nil
- (BOOL)isSortedChronologically;

@property(nonatomic, copy) NSNumber *collectionSortAscending;    // BOOL


#pragma mark Sorted Children
- (NSArray *)sortedChildren;
- (void)moveChild:(SVSiteItem *)child toIndex:(NSUInteger)index;


#pragma mark Sorting Support
- (NSArray *)childrenWithSorting:(SVCollectionSortOrder)sortType
                       ascending:(BOOL)ascending
                         inIndex:(BOOL)ignoreDrafts;

+ (NSArray *)unsortedPagesSortDescriptors;
+ (NSArray *)alphabeticalTitleTextSortDescriptorsAscending:(BOOL)ascending;
+ (NSArray *)dateCreatedSortDescriptorsAscending:(BOOL)ascending;
+ (NSArray *)dateModifiedSortDescriptorsAscending:(BOOL)ascending;


#pragma mark Hierarchy Queries
- (BOOL)isRootPage; // like NSTreeNode, the root page is defined to be one with no parent. This is just a convenience around that
- (KTPage *)parentOrRoot;
- (BOOL)hasChildren;

- (NSIndexPath *)indexPath;

#pragma mark Navigation Arrows
@property(nonatomic, copy) NSNumber *showNavigationArrows;

@end


@interface KTPage (Indexes)
// Simple Accessors
- (KTCollectionSummaryType)collectionSummaryType;
- (void)setCollectionSummaryType:(KTCollectionSummaryType)type;

// Index
- (KTAbstractIndex *)index;
- (NSArray *)pagesInIndex;
- (void)invalidatePagesInIndexCache;

// Navigation Arrows
- (NSArray *)navigablePages;
- (KTPage *)previousPage;
- (KTPage *)nextPage;


// RSS Feed
- (BOOL)collectionCanSyndicate;
- (BOOL)collectionSyndicate;
- (void)setCollectionSyndicate:(BOOL)syndicate;

@property(nonatomic, copy) NSString *RSSFileName;
- (NSURL *)feedURL;

- (NSString *)RSSFeedWithParserDelegate:(id)parserDelegate;


// Summary
- (NSString *)summaryHTMLWithTruncation:(unsigned)truncation;

- (NSString *)customSummaryHTML;
- (void)setCustomSummaryHTML:(NSString *)HTML;

- (NSString *)titleListHTMLWithSorting:(SVCollectionSortOrder)sortType;


#pragma mark Archive
@property(nonatomic, copy) NSNumber *collectionGenerateArchives;    // BOOL, required
- (KTArchivePage *)archivePageForTimestamp:(NSDate *)timestamp createIfNotFound:(BOOL)flag;
- (NSArray *)sortedArchivePages;


@end


@interface KTPage (Web)
+ (NSString *)pageTemplate;

- (BOOL)shouldPublishHTMLTemplate;

- (NSString *)javascriptURLPath;
- (NSString *)comboTitleText;

- (NSString *)DTD;
@end


@interface NSObject (KTPageDelegate)
- (BOOL)pageShouldClearThumbnail:(KTPage *)page;
- (BOOL)shouldMaskCustomSiteOutlinePageIcon:(KTPage *)page;
- (NSArray *)pageWillReturnFeedEnclosures:(KTPage *)page;

- (BOOL)pageShouldPublishHTMLTemplate:(KTPage *)page;

- (NSString *)summaryHTMLKeyPath;
- (BOOL)summaryHTMLIsEditable;
@end
