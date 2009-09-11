//
//  SVEditingOverlayItem.h
//  Sandvox
//
//  Created by Mike on 09/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVEditingOverlayItem <NSObject>

/*  The item's placement within the document view. i.e. 0,0 will place you at the top-left of the doc. 10,10 will set it 10 pixels to the right, and 10 pixels down the document.
 */
@property(nonatomic, readonly) NSRect rect;

@end
