//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "SVEditingOverlayItem.h"
#import "SVDOMNodeBoundsTracker.h"


@interface SVWebContentItem : NSObject <SVEditingOverlayItem, SVDOMNodeBoundsTrackerDelegate>
{
  @private
    DOMElement  *_element;
        
    SVDOMNodeBoundsTracker  *_nodeTracker;
}

- (id)initWithElement:(DOMElement *)element;

@property(nonatomic, retain, readonly) DOMElement *DOMElement;

@end
