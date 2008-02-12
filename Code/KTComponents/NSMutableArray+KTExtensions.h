//
//  NSMutableArray+KTExtensions.h
//  KTComponents
//
//  Created by Terrence Talbot on 5/2/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSMutableArray ( KTExtensions )

- (void)fastAddObjectsFromArray:(NSArray *)anArray;

- (void)moveObjectAtIndex:(unsigned)oldIndex toIndex:(unsigned)newIndex;

@end
