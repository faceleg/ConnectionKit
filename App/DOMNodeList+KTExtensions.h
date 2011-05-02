//
//  DOMNodeList+KTExtensions.h
//  Marvel
//
//  Created by Mike on 11/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/DOMCore.h>


@interface DOMNodeList (KTExtensions)
- (unsigned)indexOfItemIdenticalTo:(DOMNode *)item;
@end
