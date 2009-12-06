//
//  SVWebContentObjectsController.h
//  Sandvox
//
//  Created by Mike on 06/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Controller for all the selectable objects you see in the Web Editor. Customises NSArrayController to have the correct object removal behaviour.


#import "KSArrayController.h"


@class KTPage;


@interface SVWebContentObjectsController : KSArrayController
{
    KTPage  *_page;
}

// Provides extra cotnextual information on top of -managedObjectContext
@property(nonatomic, retain) KTPage *page;

@end
