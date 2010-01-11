//
//  KTURLFormatter.h
//  Marvel
//
//  Created by Mike on 15/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTURLFormatter : NSFormatter

- (NSURL *)URLFromString:(NSString *)string;    // convenience

@end
