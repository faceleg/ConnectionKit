//
//  SVSiteItem.h
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  Everything you see in the Site Outline should be a subclass of SVSiteItem. It:
//  -   Holds a reference to the parent page.
//  -   Returns NSNotApplicableMarker instead of throwing an exception for unknown keys


#import "KSExtensibleManagedObject.h"
#import "SVPageProtocol.h"
#import "SVPublisher.h"

#import <iMedia/IMBImageItem.h>


typedef enum {
    SVThumbnailTypeNone,
    SVThumbnailTypeCustom,
    SVThumbnailTypePickFromPage,
    SVThumbnailTypeFirstChildItem,
    SVThumbnailTypeLastChildItem,
} SVThumbnailType;


@class KTSite, KTMaster, KTPage, KTCodeInjection, SVExternalLink, SVMediaRecord, SVHTMLContext;
@protocol SVWebContentViewController, SVMedia;


@interface SVSiteItem : KSExtensibleManagedObject <SVPage, SVPublishedObject, IMBImageItem>
{
  @public
    id  _proxy; // weak ref, managed by the SVPageProxy
}

#pragma mark Identifier
@property(nonatomic, copy, readonly) NSString *uniqueID;
@property(nonatomic, copy, readonly) NSString *identifier;
+ (SVSiteItem *)siteItemForPreviewPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)context;


#pragma mark Title
@property(nonatomic, copy) NSString *title; // implemented as @dynamic
- (void)writeTitle:(id <SVPlugInContext>)context;   // uses rich txt/html when available


#pragma mark Dates
@property(nonatomic, copy) NSDate *creationDate;
@property(nonatomic, copy) NSDate *modificationDate;


#pragma mark Keywords
@property(nonatomic, copy) NSArray *keywords;


#pragma mark Navigation

@property(nonatomic, copy) NSNumber *includeInSiteMenu; // setting in GUI
- (BOOL)shouldIncludeInSiteMenu;    // takes into account draft status etc.

@property(nonatomic, copy, readonly) NSString *menuTitle;   // derived from .customMenuTitle or .title
@property(nonatomic, copy) NSString *customMenuTitle;

@property(nonatomic, copy) NSNumber *includeInSiteMap;    // BOOL, mandatory
@property(nonatomic, retain) NSNumber *openInNewWindow; // BOOL, mandatory


#pragma mark Drafts and Indexes

@property(nonatomic, copy) NSNumber *isDraft;
- (BOOL)isDraftOrHasDraftAncestor;
- (void)setPageOrParentDraft:(BOOL)inDraft;
- (BOOL)excludedFromSiteMap;
- (BOOL) isPagePublishableInDemo;
@property(nonatomic, copy) NSNumber *includeInIndex;


#pragma mark URL

@property(nonatomic, copy, readonly) NSURL *URL;    // nil by default, for subclasses to override

// Will publishing result in a file or directory being created that corresponds to this item? If so, return its filename (so for collections, this ignores the index.html file). Otherwise, nil
- (NSString *)filename;
- (NSString *)preferredFilename;
- (NSString *)suggestedFilename;

- (NSString *)previewPath;


#pragma mark Editing
- (KTPage *)pageRepresentation; // default returns nil. KTPage returns self so Web Editor View Controller can handle
- (SVExternalLink *)externalLinkRepresentation;	// default returns nil. used to determine if it's an external link, for page details.
- (SVMediaRecord *)mediaRepresentation;

- (BOOL) canPreview;

#pragma mark Publishing
@property(nonatomic, copy) NSDate *datePublished;
- (void)recursivelyInvalidateURL:(BOOL)recursive;


#pragma mark Site
@property(nonatomic, retain) KTSite *site;
- (void)setSite:(KTSite *)site recursively:(BOOL)recursive;
@property(nonatomic, retain, readonly) KTMaster *master;


#pragma mark Tree

@property(nonatomic, copy, readonly) NSSet *childItems;
- (NSArray *)sortedChildren;

//  .parentPage is marked as optional in the xcdatamodel file so subentities can choose their own rules. SVSiteItem programmatically makes .parentPage required. Override -validateParentPage:error: in a subclass to turn this off again.
@property(nonatomic, retain) KTPage *parentPage;
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;

- (KTPage *)rootPage;   // searches up the tree till it finds a page with no parent

- (BOOL)isDescendantOfCollection:(KTPage *)collection;
- (BOOL)isDescendantOfItem:(SVSiteItem *)aPotentialAncestor;

// Don't bother setting this manually, get KTPage or controller to do it
@property(nonatomic) short childIndex;

- (NSIndexPath *)indexPath;


#pragma mark Contents
- (void)publish:(id <SVPublisher>)publishingEngine recursively:(BOOL)recursive;
// writes to the current HTML context. Ignore things like site title
- (void)writeContent:(SVHTMLContext *)context recursively:(BOOL)recursive;


#pragma mark Thumbnail

- (BOOL)writeThumbnail:(SVHTMLContext *)context
                 width:(NSUInteger)width
                height:(NSUInteger)height
            attributes:(NSDictionary *)attributes  // e.g. custom CSS class
               options:(SVThumbnailOptions)options;

- (BOOL)writeThumbnailImage:(SVHTMLContext *)context    // support method for subclasses to override
                   maxWidth:(NSUInteger)width           // writes only the image, not anchor
                  maxHeight:(NSUInteger)height
                     dryRun:(BOOL)dryRun;

- (void)writePlaceholderThumbnail:(SVHTMLContext *)context width:(NSUInteger)width height:(NSUInteger) height;

@property(nonatomic, copy) NSNumber *thumbnailType; // SVThumbnailType, mandatory
@property(nonatomic, retain) SVMediaRecord *customThumbnail;


#pragma mark Summary
@property(nonatomic, copy) NSString *customSummaryHTML;


#pragma mark UI

@property(nonatomic, readonly) BOOL isCollection;

- (KTCodeInjection *)codeInjection;

- (NSString *)baseExampleURLString;
- (NSURL *)_baseExampleURL;

- (BOOL)isRoot;


#pragma mark Core Data

+ (NSString *)entityName;

+ (NSArray *)allPagesInManagedObjectContext:(NSManagedObjectContext *)MOC;

+ (id)pageWithUniqueID:(NSString *)pageID inManagedObjectContext:(NSManagedObjectContext *)MOC;


#pragma mark Serialization
- (void)awakeFromPropertyList:(id)propertyList parentItem:(SVSiteItem *)parent;


@end




