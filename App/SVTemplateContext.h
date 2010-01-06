//
//  SVTemplateContext.h
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SVTemplateContext : NSObject

#pragma mark Primitive Methods
// You MUST implement this in a concrete subclass
- (void)writeString:(NSString *)string;

@end