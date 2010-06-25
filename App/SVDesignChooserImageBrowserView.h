//
//  SVDesignChooserImageBrowserView.h
//  Sandvox
//
//  Created by Dan Wood on 12/8/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@interface SVDesignChooserImageBrowserView : IKImageBrowserView {

	Class _cellClass;

}



@end

@interface IKImageBrowserView (privateAPIOhNo)
- (void)_expandButtonClicked:(NSDictionary *)dict;
- (void)reloadCellDataAtIndex:(int) index;
- (void)setIntercellSpacing:(NSSize)aSpacing;
@end
