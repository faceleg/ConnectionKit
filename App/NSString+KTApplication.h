//
//  NSString+KTApplication.h
//  Marvel
//
//  Created by Dan Wood on 7/28/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSString ( KTApplication )
- (NSString *)domainName;
- (BOOL) looksLikeValidHost;
@end

