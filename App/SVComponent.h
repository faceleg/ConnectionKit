//
//  SVComponent.h
//  Sandvox
//
//  Created by Mike on 20/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@class SVHTMLContext, SVDOMController;
@protocol SVGraphic;


@protocol SVComponent <NSObject>

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID node:(DOMNode *)document;

@optional
// Override to call -beginGraphicContainer etc. if you're not happy with default behaviour
- (void)write:(SVHTMLContext *)context graphic:(id <SVGraphic>)graphic;

@end


