//
//  SVCollectionPagesController.h
//  Sandvox
//
//  Created by Mike on 30/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTPage.h"


@interface SVCollectionPagesController : NSArrayController {

}

+ (SVCollectionPagesController *)pagesControllerWithCollection:(KTPage *)page;

@end
