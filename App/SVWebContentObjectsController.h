//
//  SVWebContentObjectsController.h
//  Sandvox
//
//  Created by Mike on 06/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Controller for all the selectable objects you see in the Web Editor. Customises NSArrayController to have the correct object removal behaviour.


#import "KSArrayController.h"


@class KTPage, SVPagelet, SVSidebarPageletsController;


@interface SVWebContentObjectsController : KSArrayController
{
  @private
    KTPage                      *_page;
    SVSidebarPageletsController *_sidebarPageletsController;
}

// More specialised than -newObject
- (SVPagelet *)newPagelet;
- (BOOL)sidebarPageletAppearsOnAncestorPage:(SVPagelet *)pagelet;

// Provides extra contextual information on top of -managedObjectContext
@property(nonatomic, retain) KTPage *page;


- (BOOL)selectObjectByInsertingIfNeeded:(id)object;


#pragma mark  SPI
@property(nonatomic, retain, readonly) SVSidebarPageletsController *sidebarPageletsController;

@end
