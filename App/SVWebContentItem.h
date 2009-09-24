//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "SVWebEditorItem.h"
#import "SVDOMNodeBoundsTracker.h"


@class KTPagelet;


@interface SVWebContentItem : NSObject <SVWebEditorItem, SVDOMNodeBoundsTrackerDelegate>
{
  @private
    DOMElement  *_DOMElement;
    KTPagelet   *_pagelet;
        
    SVDOMNodeBoundsTracker  *_nodeTracker;
}

- (id)initWithDOMElement:(DOMElement *)element;
- (id)initWithDOMElement:(DOMElement *)element pagelet:(KTPagelet *)pagelet;

@property(nonatomic, retain, readonly) DOMElement *DOMElement;
@property(nonatomic, retain, readonly) KTPagelet *pagelet;

@end
