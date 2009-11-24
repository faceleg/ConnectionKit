//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVWebEditorItem.h"


@class SVWebTextArea;


@interface SVWebContentItem : SVWebEditorItem
{
  @private
    NSMutableArray  *_textAreas;
    
    BOOL    _editable;
}

@property(nonatomic, readonly) NSArray *textAreas;
- (void)insertObject:(SVWebTextArea *)textArea inTextAreasAtIndex:(NSUInteger)index;
- (void)removeObjectFromTextAreasAtIndex:(NSUInteger)index;

@property(nonatomic, getter=isEditable) BOOL editable;

@end
