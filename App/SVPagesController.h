//
//  KTDocSiteOutlineController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTPage;


@interface SVPagesController : NSArrayController
{
  @private
    NSDictionary    *_presetDict;
    NSURL           *_fileURL;
}

// To create a new page/item:
//  1.  Set .entityName to what you want. Should be Page, ExternalLink, or File.
//  2.  Optionally, specify any additional info through -setCollectionPreset: or -setFileURL:
//  3.  Call one of: -add: -newObject -newObjectWithPredecessor:
@property(nonatomic, copy) NSString *entityName;
@property(nonatomic, copy) NSDictionary *collectionPreset;
@property(nonatomic, copy) NSURL *fileURL;

- (void)addObject:(id)object toCollection:(KTPage *)parent;
- (void)addObjectsFromPasteboard:(NSPasteboard *)pboard toCollection:(KTPage *)collection;

// Doesn't add the result to collection, just uses it to determine property inheritance
- (id)newObjectDestinedForCollection:(KTPage *)collection;

- (NSString *)childrenKeyPath;	// A hangover from NSTreeController

@end