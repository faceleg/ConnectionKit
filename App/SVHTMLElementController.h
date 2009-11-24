//
//  SVHTMLElementController.h
//  Sandvox
//
//  Created by Mike on 24/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVHTMLElementController : NSResponder
{
  @private
    DOMHTMLElement  *_DOMElement;
    id              _representedObject;
}

#pragma mark Init
- (id)initWithHTMLElement:(DOMHTMLElement *)element;    // convenience


@property(nonatomic, retain) DOMHTMLElement *HTMLElement;
- (void)loadHTMLElement;
@property(nonatomic, readonly, getter=isHTMLElementLoaded) BOOL HTMLElementLoaded;


@property(nonatomic, retain) id representedObject;

@end
