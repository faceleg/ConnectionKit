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

- (SVDOMController *)newDOMControllerWithElementIdName:(NSString *)elementID ancestorNode:(DOMNode *)document;

@optional
// Much like -webView:doCommandBySelector:
// Return yes if you want do custom overriting, making sure to call -beginGraphicContainer etc. in your custom implementation
- (BOOL)HTMLContext:(SVHTMLContext *)context writeGraphic:(id <SVGraphic>)graphic;

@end


