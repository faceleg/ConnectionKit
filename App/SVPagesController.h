//
//  SVPagesController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//
//  We've not been very good at model controllers, but hopefully are getting better. SVPagesController is (surprise, surprise) a model controller that manages pages in a site. Although these days it actually manages SVSiteItem objects.
//  What's strange, is that even though it's aware of the page hierarchy in a site, SVPagesController is actually an NSArrayController subclass. It holds together for now, and maybe we'll move to a tree controller later.
//  Main advantage offered is that manipulating the array controller handles that like you would expect from the UI, so:
//      - Creating new pages gives them appropriate starting properties
//      - Inserting or moving a page ensures its URL is unique within the site
//      - Changing a page's filename marks it as customised so that it will no longer automatically change to match title
//
//  That sort of logic all used to be in the model, but you end up trying to do too much in one place.

#import "KSArrayController.h"


extern NSString *SVPagesControllerDidInsertObjectNotification;


@class KTPage, SVPageTemplate;
@protocol SVPage, SVPasteboardItem;


@interface SVPagesController : KSArrayController
{
  @private
    SVPageTemplate  *_template;
    NSURL           *_URL;
}

#pragma mark Creating a Pages Controller
+ (SVPagesController *)controllerWithPagesInCollection:(id <SVPage>)collection;
+ (NSArrayController *)controllerWithPagesToIndexInCollection:(id <SVPage>)collection;


#pragma mark Core Data Support

// Sets the controller up to produce regular pages. Optional template specifies how to populate the new page
- (void)setEntityNameWithPageTemplate:(SVPageTemplate *)pageTemplate;
@property(nonatomic, retain, readonly) SVPageTemplate *pageTemplate;

// Sets the controller up to produce File Downloads or External Link pages. If URL is nil for an external link, controller will attempt to guess it at insert-time
- (void)setEntityTypeWithURL:(NSURL *)URL external:(BOOL)external;
@property(nonatomic, copy, readonly) NSURL *objectURL;

// Overriden to reset pageTemplate and objectURL
- (void)setEntityName:(NSString *)entityName;


#pragma mark Managing Objects
- (BOOL)canGroupAsCollection;


#pragma mark Pasteboard Support
- (BOOL)addObjectsFromPasteboard:(NSPasteboard *)pboard;
- (id)newObjectFromPasteboardItem:(id <SVPasteboardItem>)pboardItem parentPage:(KTPage *)collection;


@end
