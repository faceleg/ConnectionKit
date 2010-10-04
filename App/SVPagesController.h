//
//  KTDocSiteOutlineController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//
//  We've not been very good at model controllers, but hopefully are getting better. SVPagesController is (surprise, surprise) a model controller that manages pages in a site. Although these days it actually manages SVSiteItem objects.
//  What's strange, is that even though it's aware of the page hierarchy in a site, SVPagesController is actually an NSArrayController subclass. It holds together for now, and maybe we'll move to a tree controller later.
//  Main advantage offered is that manipulating the array controller handles that like you would expect from the UI, so:
//      - Creating new pages gives them appropriate starting properties
//      - Inserting or moving a page ensures its URL is unique within the site
//      - Changing a page's filename marks it as customised so that it will no longer automatically change to match title
//
//  That sort of logic all used to be in the model, but you end up trying to do too much in one place.

#import <Cocoa/Cocoa.h>


@class KTPage;
@protocol SVPagesControllerDelegate;


@interface SVPagesController : NSArrayController
{
  @private
    NSDictionary    *_presetDict;
    NSURL           *_fileURL;
    
    id <SVPagesControllerDelegate>  _delegate;  // weak ref
}

#pragma mark Creating a Pages Controller
+ (NSArrayController *)controllerWithPagesInCollection:(KTPage *)collection;
+ (NSArrayController *)controllerWithPagesToIndexInCollection:(KTPage *)collection;


#pragma mark Managing Objects

// To create a new page/item:
//  1.  Set .entityName to what you want. Should be Page, ExternalLink, or File.
//  2.  Optionally, specify any additional info through -setCollectionPreset: or -setFileURL:
//  3.  Call one of: -add: -newObject -newObjectWithPredecessor:
@property(nonatomic, copy) NSString *entityName;
@property(nonatomic, copy) NSDictionary *collectionPreset;
@property(nonatomic, copy) NSURL *fileURL;

- (void)addObject:(id)object toCollection:(KTPage *)collection;
- (BOOL)addObjectsFromPasteboard:(NSPasteboard *)pboard toCollection:(KTPage *)collection;

- (void)moveObject:(id)object toCollection:(KTPage *)collection index:(NSUInteger)index;

// Doesn't add the result to collection, just uses it to determine property inheritance
- (id)newObjectDestinedForCollection:(KTPage *)collection;


#pragma mark Tree
- (NSString *)childrenKeyPath;	// A hangover from NSTreeController


#pragma mark Delegate
@property(nonatomic, assign) id <SVPagesControllerDelegate> delegate;


@end


#pragma mark -


@protocol SVPagesControllerDelegate
- (KTPage *)collectionForPagesControllerToAddObjectsTo:(SVPagesController *)sender;
@end

