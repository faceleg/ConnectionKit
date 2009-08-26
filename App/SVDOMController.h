//
//  SVDOMElementController.h
//  Marvel
//
//  Created by Mike on 21/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Central to Sandvox 2.0's architecture for interacting with WebKit are DOM Element Controllers. The aim is to take the concept of window controllers and view controllers and create another, similar class dedicated to handling an area of the webview.


#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


// TODO: Implement <NSCoding> as NSResponder would like
@interface SVDOMController : NSResponder
{
    DOMHTMLElement  *_element;
}

@property(nonatomic, retain) DOMHTMLElement *DOMElement;
- (void)loadDOMElement;
@property(nonatomic, readonly) BOOL DOMElementIsLoaded;

@end
