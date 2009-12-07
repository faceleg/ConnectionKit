//
//  KTDocSiteOutlineController.h
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTPage, KTDocument, KTDocWindowController;


@interface SVPagesController : NSArrayController
{
  @private
}

// Use -add: to create a regular page. -addCollection: for collections
- (IBAction)addCollection:(id)sender;

- (void)addPage:(KTPage *)page asChildOfPage:(KTPage *)parent;

- (NSString *)childrenKeyPath;	// A hangover from NSTreeController

@end