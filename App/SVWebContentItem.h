//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVDOMController.h"


@class SVWebEditorTextController;


@interface SVWebContentItem : SVDOMController
{
  @private
    NSMutableArray  *_textAreas;
    
    BOOL    _editable;
}

@property(nonatomic, readonly) NSArray *textAreas;
- (void)insertObject:(SVWebEditorTextController *)textArea inTextAreasAtIndex:(NSUInteger)index;
- (void)removeObjectFromTextAreasAtIndex:(NSUInteger)index;

@property(nonatomic, getter=isEditable) BOOL editable;

@end
