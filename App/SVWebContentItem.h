//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVWebEditorItem.h"

#import "SVDOMNodeBoundsTracker.h"


@class SVPagelet;


@interface SVWebContentItem : SVWebEditorItem <SVDOMNodeBoundsTrackerDelegate>
{
  @private
    SVPagelet   *_pagelet;
}

- (id)initWithDOMElement:(DOMElement *)element pagelet:(SVPagelet *)pagelet;

@property(nonatomic, retain, readonly) SVPagelet *pagelet;

@end
