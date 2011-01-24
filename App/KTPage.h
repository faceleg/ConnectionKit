//
//  KTPage.h
//  Sandvox
//
//  Copyright 2005-2011 Karelia Software. All rights reserved.
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

#import "SVSiteItem.h"
#import "NSManagedObject+KTExtensions.h"


typedef enum {
	SVCollectionSortManually,   // default as of 2.0
    SVCollectionSortAlphabetically,
    SVCollectionSortByDateCreated,
	SVCollectionSortByDateModified,
    SVCollectionSortOrderUnspecified = -1,		// used internally
} SVCollectionSortOrder;


@class SVArticle, KTMaster, SVSidebar, SVPageTitle, SVRichText, SVGraphic, SVMediaRecord, KTCodeInjection, SVHTMLContext;


@interface KTPage : SVSiteItem

#pragma mark Title
@property(nonatomic, retain) SVPageTitle *titleBox;  // you can use inherited .title property for ease of use too
- (BOOL)canEditTitle;


#pragma mark Body
@property(nonatomic, retain, readonly) SVArticle *article;
@property(nonatomic, copy) NSString *masterIdentifier;


#pragma mark Properties
@property(nonatomic, retain, readonly) SVSidebar *sidebar;
@property(nonatomic, copy) NSNumber *showSidebar;


#pragma mark Paths
@property(nonatomic, copy) NSString *customPathExtension;
@property(nonatomic, copy) NSString *customIndexAndPathExtension;


#pragma mark Thumbnail
@property(nonatomic, retain) SVGraphic *thumbnailSourceGraphic;


#pragma mark Debugging
- (NSString *)shortDescription;

@end


#pragma mark -


@interface KTPage (Accessors)

#pragma mark Comments
@property(nonatomic, copy, readwrite) NSNumber *allowComments;


#pragma mark Title
@property(nonatomic) BOOL shouldUpdateFileNameWhenTitleChanges;


#pragma mark Timestamp

- (NSString *)timestamp;
- (NSString *)timestampWithStyle:(NSDateFormatterStyle)aStyle;
- (NSDate *)timestampDate;

@property(nonatomic, copy) NSNumber *includeTimestamp;

@property(nonatomic, copy) NSNumber *timestampType; // KTTimestampType
- (NSString *)timestampTypeLabel;   // not KVO-compliant yet, but could easily be


#pragma mark Keywords
- (NSString *)keywordsList;


#pragma mark Search Engines
@property(nonatomic, copy) NSString *metaDescription;
@property(nonatomic, copy) NSString *windowTitle;


@end


#pragma mark -


@interface KTPage (Children)

#pragma mark Children
@property(nonatomic, copy, readonly) NSSet *childItems;


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

- (NSArray *)childItemsSortDescriptors;

+ (NSArray *)unsortedPagesSortDescriptors;
+ (NSArray *)alphabeticalTitleTextSortDescriptorsAscending:(BOOL)ascending;
+ (NSArray *)dateCreatedSortDescriptorsAscending:(BOOL)ascending;
+ (NSArray *)dateModifiedSortDescriptorsAscending:(BOOL)ascending;


#pragma mark Hierarchy Queries
- (BOOL)isRootPage; // like NSTreeNode, the root page is defined to be one with no parent. This is just a convenience around that
- (KTPage *)parentOrRoot;
- (BOOL)hasChildren;
@property(nonatomic) BOOL isCollection;
@property(nonatomic, readonly) BOOL willPublishAsCollection;    // dummy setter for binding to


#pragma mark Navigation Arrows
@property(nonatomic, copy) NSNumber *navigationArrowsStyle; // collection property


@end


#pragma mark -


@interface KTPage (Indexes)

@property(nonatomic, copy) NSNumber *collectionSummaryType;  // KTCollectionSummaryType

#pragma mark Navigation Arrows

- (NSArray *)navigablePages;

// NOT KVO-compliant, but do register the required dependencies with current context
- (KTPage *)previousPage;
- (KTPage *)nextPage;

+ (SVTruncationType) chooseTruncTypeFromMaxItemLength:(NSUInteger)maxItemLength;


#pragma mark Syndication

@property(nonatomic, copy) NSNumber *collectionSyndicationType;  // SVSyndicationType, mandatory

// Mandatory for collections, nil otherwise:
@property(nonatomic, copy) NSNumber *collectionMaxSyndicatedPagesCount;   

@property(nonatomic, copy) NSNumber *collectionTruncateFeedItems;   // BOOL, mandatory
@property(nonatomic, copy) NSNumber *collectionMaxFeedItemLength;

@property(nonatomic, copy) NSString *RSSFileName;
@property(nonatomic, readonly) NSURL *feedURL;  // KVO-compliant

- (NSString *)RSSFeed;
- (void)writeRSSFeed:(SVHTMLContext *)context;
- (void)writeRSSFeedItemDescription;


#pragma mark RSS Enclosures
- (NSArray *)feedEnclosures;
- (void)guessEnclosures;    // searches for enclosures if feed expects them

//@property(nonatomic, copy) NSNumber *collectionSyndicateWithParent;  // "the idea is that you would have a blog collection with a blog collection *inside* -- sort of a sub-blog.  If this is checked, it would mean that we want the contents of that sub-blog to also show up in the RSS feed for the enclosing blog. I think it's a cool idea, just never got around to making it work!"


#pragma mark Summary


#pragma mark Archive
@property(nonatomic, copy) NSNumber *collectionGenerateArchives;    // BOOL, required


@end


#pragma mark -


@interface KTPage (Web)

- (NSString *)markupString;   // HTML for publishing/viewing. Calls -writeDocumentWithPage: on a temp context
- (NSString *)markupStringForEditing;   // for viewing source for debugging purposes.
+ (NSString *)pageTemplate;

- (NSString *)javascriptURLPath;
- (NSString *)comboTitleText;

- (void)write:(SVHTMLContext *)context codeInjectionSection:(NSString *)aKey masterFirst:(BOOL)aMasterFirst;

+ (NSString *)stringFromDocType:(KTDocType)docType local:(BOOL)isLocal;		// UTILITY

- (NSString *)commentsTemplate;	// instance method too for key paths to work in tiger

@end


#pragma mark -


@interface KTPage (Serialization)
+ (KTPage *)deserializingPageForIdentifier:(NSString *)identifier;
@end

