//
//  DOM+WebViewTextEditing.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DOMNode (KTWebViewController)

- (DOMHTMLElement *)firstSelectableParentNode;

- (void)replaceWithText:(NSString *)aText;

@end


@interface DOMHTMLElement (KTWebViewController)
- (BOOL)isImageable;
- (BOOL)hasSpanIn;

- (void)unstyleWithBlacklist:(NSSet *)whitelist;

@end
