//
//  SVSiteItem.h
//  Sandvox
//
//  Created by Mike on 13/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

//  Everything you see in the Site Outline should be a subclass of SVSiteItem. It:
//  -   Holds a reference to the parent page.
//  -   Returns NSNotApplicableMarker instead of throwing an exception for unknown keys


#import "SVExtensibleManagedObject.h"


@class KTSite, KTPage, KTCodeInjection, SVExternalLink;
@protocol SVWebContentViewController, SVMedia;


@interface SVSiteItem : SVExtensibleManagedObject  

#pragma mark Title
@property(nonatomic, copy) NSString *title; // implemented as @dynamic


#pragma mark Dates
@property(nonatomic, copy) NSDate *creationDate;
@property(nonatomic, copy) NSDate *lastModificationDate;


#pragma mark Site Menu

@property(nonatomic) BOOL includeInSiteMenu;

@property(nonatomic, copy, readonly) NSString *menuTitle;   // derived from .customMenuTitle or .title
@property(nonatomic, copy) NSString *customMenuTitle;


#pragma mark Drafts and Indexes

@property(nonatomic, copy) NSNumber *isDraft;
- (BOOL)pageOrParentDraft;
- (void)setPageOrParentDraft:(BOOL)inDraft;
- (BOOL)excludedFromSiteMap;

@property(nonatomic) BOOL includeInIndex;


#pragma mark URL
@property(nonatomic, copy, readonly) NSURL *URL;    // nil by default, for subclasses to override
@property(nonatomic, copy, readonly) NSString *fileName;    // nil by default, for subclasses to override


#pragma mark Editing
- (KTPage *)pageRepresentation; // default returns nil. KTPage returns self so Web Editor View Controller can handle
- (SVExternalLink *)externalLinkRepresentation;	// default returns nil. used to determine if it's an external link, for page details.
- (id <SVMedia>)mediaRepresentation;

- (BOOL) canPreview;

#pragma mark Publishing
@property(nonatomic, copy) NSString *publishedPath;
- (BOOL)includeInIndexAndPublish;


#pragma mark Site
@property(nonatomic, retain) KTSite *site;
- (void)setSite:(KTSite *)site recursively:(BOOL)recursive;


#pragma mark Tree

@property(nonatomic, copy, readonly) NSSet *childItems;

//  .parentPage is marked as optional in the xcdatamodel file so subentities can choose their own rules. SVSiteItem programmatically makes .parentPage required. Override -validateParentPage:error: in a subclass to turn this off again.
@property(nonatomic, retain) KTPage *parentPage;
- (BOOL)validateParentPage:(KTPage **)page error:(NSError **)outError;

- (KTPage *)rootPage;   // searches up the tree till it finds a page with no parent

- (BOOL)isDescendantOfCollection:(KTPage *)collection;
- (BOOL)isDescendantOfItem:(SVSiteItem *)aPotentialAncestor;

// Don't bother setting this manually, get KTPage or controller to do it
@property(nonatomic) short childIndex;


#pragma mark UI

@property(nonatomic, readonly) BOOL isCollection;

- (KTCodeInjection *)codeInjection;

@end



