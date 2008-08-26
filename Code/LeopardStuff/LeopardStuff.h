//
//  LeopardStuff.h
//  LeopardStuff
//
//  Created by Dan Wood on 8/14/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface LeopardStuff : NSObject

- (void)loadLocalFontsInBundle:(NSBundle *)aBundle;

- (NSString *)symbolizeBacktrace:(NSException *)exception;

@end
