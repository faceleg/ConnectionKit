//
//  KTSiteOutlineView.h
//  Marvel
//
//  Created by Terrence Talbot on 11/29/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define LARGE_ICON_CELL_HEIGHT	34.00
#define SMALL_ICON_CELL_HEIGHT	17.00
#define LARGE_ICON_ROOT_SPACING	10.00
#define SMALL_ICON_ROOT_SPACING 10.00

#define ICON_ROOT_DIVIDER_SPACING	7.00
#define ICON_GROUP_ROW_SPACING 3.00


@interface KTSiteOutlineView : NSOutlineView
{
  @private
    // Layout/drawing
    CGFloat _homePageX;
    BOOL    _isDrawingRows;
    BOOL    _isDrawing;
	
    // Data
    BOOL    _isReloadingData;
    
    // Drag and drop
	NSIndexSet *_draggedRows;
}

@property (retain) NSIndexSet *draggedRows;

@end
