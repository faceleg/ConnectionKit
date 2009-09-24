//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import "SVWebEditorItem.h"

#import "SVDOMNodeBoundsTracker.h"


@class KTPagelet;


@interface SVWebContentItem : SVWebEditorItem <SVDOMNodeBoundsTrackerDelegate>
{
  @private
    KTPagelet   *_pagelet;
        
    SVDOMNodeBoundsTracker  *_nodeTracker;
}

- (id)initWithDOMElement:(DOMElement *)element pagelet:(KTPagelet *)pagelet;

@property(nonatomic, retain, readonly) KTPagelet *pagelet;

@end
