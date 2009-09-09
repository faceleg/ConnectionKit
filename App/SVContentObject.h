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


@interface SVContentObject : NSObject <SVEditingOverlayItem, SVDOMNodeBoundsTrackerDelegate>
{
  @private
    DOMElement  *_element;
        
    SVDOMNodeBoundsTracker  *_nodeTracker;
}

- (id)initWithDOMElement:(DOMElement *)element;

@property(nonatomic, retain, readonly) DOMElement *DOMElement;

@end
