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
#import "KTPagelet.h"
#import "NSManagedObject+KTExtensions.h"


@class KTDesign, KTAbstractHTMLPlugin;
@class KTArchivePage, KTAbstractIndex, KTMaster;
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

// Debugging
- (NSString *)shortDescription;

@end


@interface KTPage (Accessors)

- (BOOL)disableComments;
- (void)setDisableComments:(BOOL)disableComments;

// Title
- (BOOL)shouldUpdateFileNameWhenTitleChanges;
- (void)setShouldUpdateFileNameWhenTitleChanges:(BOOL)autoUpdate;

// Draft
- (void)setIsDraft:(BOOL)flag;
- (BOOL)pageOrParentDraft;
- (void)setPageOrParentDraft:(BOOL)inDraft;
- (BOOL)includeInIndexAndPublish;
- (BOOL)excludedFromSiteMap;

// Site menu
- (BOOL)includeInSiteMenu;
- (void)setIncludeInSiteMenu:(BOOL)include;

- (NSString *)menuTitle;
- (void)setMenuTitle:(NSString *)newTitle;
- (NSString *)menuTitleOrTitle;

// Timestamps
- (NSDate *)editableTimestamp;
- (void)setEditableTimestamp:(NSDate *)aDate;
- (NSString *)timestamp;
- (NSDate *) creationOrModificationDate;

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

- (BOOL)hasCodeInjection;
@end


@interface KTPage (Children)
// Basic Accessors
- (KTCollectionSortType)collectionSortOrder;
- (void)setCollectionSortOrder:(KTCollectionSortType)sorting;

- (BOOL)isCollection;

- (void)moveToIndex:(unsigned)index;

// Unsorted Children
- (NSSet *)children;
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

- (NSString *)RSSFileName;
- (void)setRSSFileName:(NSString *)file;
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


@interface KTPage (Pagelets)
// General accessors
- (BOOL)includeSidebar;
- (void)setIncludeSidebar:(BOOL)flag;
- (BOOL)includeCallout;

- (BOOL)sidebarChangeable;
- (void)setSidebarChangeable:(BOOL)flag;

// Pagelet accessors
- (NSSet *)pagelets;	// IMPORTANT: Never try to use -mutableSetValueForKey:@"pagelets"

- (NSArray *)pageletsInLocation:(KTPageletLocation)location;
- (void)insertPagelet:(KTPagelet *)pagelet atIndex:(unsigned)index;
- (void)addPagelet:(KTPagelet *)pagelet;
- (void)removePagelet:(KTPagelet *)pagelet;

- (NSArray *)callouts;	// KVO-compliant
- (void)invalidateCalloutsCache;

// All sidebar pagelets that will appear in the HTML. i.e. Our sidebars plus any inherited ones
- (NSArray *)sidebarPagelets;
- (void)invalidateSidebarPageletsCache:(BOOL)invalidateCache recursive:(BOOL)recursive;

// Support
+ (void)updatePageletOrderingsFromArray:(NSArray *)pagelets;
@end


@interface KTPage (Web)
+ (NSString *)pageTemplate;

- (NSString *)contentHTMLWithParserDelegate:(id)delegate isPreview:(BOOL)isPreview;
- (BOOL)pluginHTMLIsFullPage;
- (void)setPluginHTMLIsFullPage:(BOOL)fullPage;
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
