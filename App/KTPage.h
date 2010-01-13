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


@class KTDesign;
@class KTArchivePage, KTAbstractIndex, KTMaster, KTCodeInjection;
@class WebView;
@class KTMediaContainer;

@interface KTPage : KTAbstractPage	<KTExtensiblePluginPropertiesArchiving>
{
	@private
    // these ivars are only set if the page is root
	BOOL myIsNewPage;		// accessor is in category
}

// Awake
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary;


#pragma mark Properties
@property(nonatomic, copy) NSNumber *showSidebar;


#pragma mark Paths
@property(nonatomic, copy) NSString *customPathExtension;


#pragma mark Debugging
- (NSString *)shortDescription;

@end


#pragma mark -


@interface KTPage (Accessors)

@property(nonatomic, copy) NSNumber *allowComments;
@property(nonatomic) BOOL disableComments;

// Title
@property(nonatomic) BOOL shouldUpdateFileNameWhenTitleChanges;

// Draft
- (void)setIsDraft:(BOOL)flag;
- (BOOL)pageOrParentDraft;
- (void)setPageOrParentDraft:(BOOL)inDraft;
- (BOOL)includeInIndexAndPublish;
- (BOOL)excludedFromSiteMap;


#pragma mark Site Menu

@property(nonatomic) BOOL includeInSiteMenu;

@property(nonatomic, copy, readonly) NSString *menuTitle;   // derived from .customMenuTitle or .title
@property(nonatomic, copy) NSString *customMenuTitle;


#pragma mark Timestamp

@property(nonatomic, copy) NSDate *creationDate;
@property(nonatomic, copy) NSDate *lastModificationDate;

- (NSString *)timestamp;
- (NSString *)timestampWithStyle:(NSDateFormatterStyle)aStyle;
- (NSDate *)timestampDate;

@property(nonatomic, copy) NSNumber *includeTimestamp;

@property(nonatomic) KTTimestampType timestampType;
- (NSString *)timestampTypeLabel;   // not KVO-compliant yet, but could easily be


// Thumbnail
- (KTMediaContainer *)thumbnail;
- (void)setThumbnail:(KTMediaContainer *)thumbnail;
- (void)generateCollectionThumbnail;
- (KTPage *)pageToUseForCollectionThumbnail;

// Keywords
- (NSArray *)keywords;
- (void)setKeywords:(NSArray *)aStoredArray;
- (NSString *)keywordsList;

// Site Outline
- (KTMediaContainer *)customSiteOutlineIcon;
- (void)setCustomSiteOutlineIcon:(KTMediaContainer *)icon;

- (KTCodeInjection *)codeInjection;

@end


#pragma mark -


@interface KTPage (Children)
// Basic Accessors
@property(nonatomic) KTCollectionSortType collectionSortOrder;
- (BOOL)isChronologicallySorted;

- (BOOL)isCollection;

- (void)moveToIndex:(unsigned)index;

// Unsorted Children
@property(nonatomic, copy, readonly) NSSet *childItems;
- (void)addPage:(KTPage *)page;
- (void)removePage:(KTPage *)page;
- (void)removePages:(NSSet *)pages;

// Sorted Children
- (NSArray *)sortedChildren;
- (NSArray *)childrenWithSorting:(KTCollectionSortType)sortType inIndex:(BOOL)ignoreDrafts;

// Hierarchy Queries
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

- (BOOL)includeInIndex;
- (void)setIncludeInIndex:(BOOL)flag;

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

- (NSString *)titleListHTMLWithSorting:(KTCollectionSortType)sortType;

// Archive
- (BOOL)collectionGenerateArchives;
- (void)setCollectionGenerateArchives:(BOOL)generateArchive;
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
