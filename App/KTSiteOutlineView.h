//
//  KTSiteOutlineView.h
//  Marvel
//
//  Created by Terrence Talbot on 11/29/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTSiteOutlineView : NSOutlineView
{
  @private
    BOOL    _drawingRows;
    BOOL    _isDrawing;
	BOOL    _isReloadingData;
    
	NSIndexSet *_draggedRows;
}

@property (retain) NSIndexSet *draggedRows;

@end
