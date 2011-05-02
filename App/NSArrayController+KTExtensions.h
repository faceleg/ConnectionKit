//
//  NSArrayController+KTExtensions.h
//  KTComponents
//
//  Created by Mike on 02/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSArrayController (KTExtensions)

- (void)replaceObjectAtArrangedObjectIndex:(unsigned int)index
								withObject:(id)object;
								
@end
