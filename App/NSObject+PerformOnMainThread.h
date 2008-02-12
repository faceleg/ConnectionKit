//
//  NSObject+PerformOnMainThread.h
//  Marvel
//
//  Created by Mike on 04/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (PerformOnMainThread)
- (id)performSelectorOnMainThreadAndReturnResult:(SEL)selector;
- (id)performSelectorOnMainThreadAndReturnResult:(SEL)selector withObject:(id)argument;
- (id)performSelectorOnMainThreadAndReturnResult:(SEL)selector withObject:(id)argument withObject:(id)argument2;
@end
