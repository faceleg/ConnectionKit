//
//  SVWebContentItem.h
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "SVDOMNodeBoundsTracker.h"


@interface SVContentObject : NSViewController <SVDOMNodeBoundsTrackerDelegate>
{
  @private
    DOMElement  *_element;
        
    SVDOMNodeBoundsTracker  *_nodeTracker;
    
    BOOL    _isSelected;
    NSView  *_selectionHandlesView;
}

- (id)initWithDOMElement:(DOMElement *)element;

@property(nonatomic, retain, readonly) DOMElement *DOMElement;




@property(nonatomic, getter=isSelected) BOOL selected;

@end
