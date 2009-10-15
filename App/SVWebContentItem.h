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
    id              _representedObject;
    NSMutableArray  *_textAreas;
}

@property(nonatomic, retain) id representedObject;

@property(nonatomic, readonly) NSArray *textAreas;
- (void)insertObject:(SVWebTextArea *)textArea inTextAreasAtIndex:(NSUInteger)index;
- (void)removeObjectFromTextAreasAtIndex:(NSUInteger)index;

@end
