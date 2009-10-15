//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVWebEditorItem.h"


@interface SVWebContentItem : SVWebEditorItem
{
  @private
    id  _representedObject;
}

@property(nonatomic, retain) id representedObject;

@end
