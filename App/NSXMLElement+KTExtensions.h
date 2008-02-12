//
//  NSXMLElement+KTExtensions.h
//  Marvel
//
//  Created by Mike on 01/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSXMLElement (KTExtensions)
- (void) removeAllNodesAfter:(NSXMLElement *)lastNode;
@end
