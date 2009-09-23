//
//  SVEditingOverlayItem.h
//  Sandvox
//
//  Created by Mike on 09/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVEditingOverlayItem <NSObject>

- (DOMElement *)DOMElement;

/*  Return YES or NO to indicate whether a drag should commence
 */
- (BOOL)writeToPasteboard:(NSPasteboard *)pasteboard;

@end
