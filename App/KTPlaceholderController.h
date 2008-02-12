//
//  KTPlaceholderController.h
//  Marvel
//
//  Created by Dan Wood on 10/16/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTPlaceholderController : NSWindowController {

}

+ (KTPlaceholderController *)sharedPlaceholderController;
+ (KTPlaceholderController *)sharedPlaceholderControllerWithoutLoading;

- (IBAction) doNew:(id)sender;

- (IBAction) doOpen:(id)sender;


@end
