//
//  KTParsedWebViewComponent.h
//  Marvel
//
//  Created by Mike on 24/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//
//	Represents an object that was parsed with an HTML template to form a portion of a page's HTML.
//	KTDocWebViewController maintains the hierarchy of these objects.


#import <Cocoa/Cocoa.h>
#import "KTHTMLParser.h"

#import "KTWebViewComponentProtocol.h"


@class KTDocWebViewController;


@interface KTWebViewComponent : NSObject <KTHTMLParserDelegate>
{
	KTHTMLParser	*myParser;
	
	NSString	*myInnerHTML;
    NSString	*myComponentHTML;
	
	NSMutableSet			*myTextBlocks;
    
	NSMutableArray			*mySubcomponents;
	KTWebViewComponent		*mySupercomponent;		// Weak ref
	KTDocWebViewController	*myWebViewController;	// Weak ref
}

- (id)initWithParser:(KTHTMLParser *)parser;

- (KTHTMLParser *)parser;
- (NSString *)divID;

- (NSString *)outerHTML;
- (NSString *)componentHTML;

- (NSSet *)textBlocks;
- (void)addTextBlock:(KTHTMLTextBlock *)textBlock;
- (void)removeAllTextBlocks;
- (KTHTMLTextBlock *)textBlockForDOMNode:(DOMNode *)node;

- (NSArray *)subcomponents;
- (void)addSubcomponent:(KTWebViewComponent *)component;
- (void)replaceWithComponent:(KTWebViewComponent *)replacementComponent;
- (void)removeAllSubcomponents;

- (KTWebViewComponent *)supercomponent;

- (KTDocWebViewController *)webViewController;
- (void)setWebViewController:(KTDocWebViewController *)webViewController;

#pragma mark Loading
- (void)_reloadIfNeededWithPossibleReplacement:(KTWebViewComponent *)replacementComponent;

@end
