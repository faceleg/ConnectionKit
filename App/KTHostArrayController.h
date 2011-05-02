//
//  KTHostArrayController.h
//  Marvel
//
//  Created by Dan Wood on 11/10/04.
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KTHostArrayController : NSArrayController {

	NSString *mySearchString;

}
- (IBAction)search:(id)sender;

- (NSString *)searchString;
- (void)setSearchString:(NSString *)aSearchString;
- (NSArray *)arrangeObjects:(NSArray *)objects;

@end
