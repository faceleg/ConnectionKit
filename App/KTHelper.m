//
//  KTHelper.m
//  Marvel
//
//  Created by Mike on 27/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTHelper.h"

#import "KTDocWindowController.h"
#import "KTDocWebViewController.h"
#import "KTWebViewComponent.h"
#import "SVHTMLTextBlock.h"

#import "DOMNode+KTExtensions.h"
#import "DOM+KTWebViewController.h"


@implementation KTHelper

- (id)initWithWindowController:(id)aWindowController
{
	if (self = [super init])
	{
		myWindowController = aWindowController;		// NOT RETAINED
	}
	return self;
}


- (id)controller { return myWindowController; }


/*!	Called from javascript "replaceElement" ... pressing of "+" button ... puts back an element that was empty
*/
- (void)replace:(DOMNode *)aNode withElementName:(NSString *)anElement elementClass:(NSString *)aClass elementID:(NSString *)anID text:(NSString *)aText innerSpan:(BOOL)aSpan innerParagraph:(BOOL)aParagraph
{
	DOMHTMLElement *newElement = [aNode replaceWithElementName:anElement elementClass:aClass elementID:anID text:aText innerSpan:aSpan innerParagraph:aParagraph];

	// Get it ready to edit (take off image substitution)
	SVHTMLTextBlock *textBlock = [[[myWindowController webViewController] mainWebViewComponent] textBlockForDOMNode:newElement];
	
	if (textBlock)
	{
		// We focus the text block and then the WebViewController does the work of setting up editing properly
		[[textBlock DOMNode] focus];
	}
}


/*!	Called from javascript "replaceText" -- replace the node with just some text.
*/
- (void)replace:(DOMNode *)aNode withText:(NSString *)aText
{
	[aNode replaceWithText:aText];
}




+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel
{
	return (sel != @selector(replace:withElementName:elementClass:elementID:text:innerSpan:innerParagraph:)
			&&  sel != @selector(replace:withText:));
}
+ (NSString *) webScriptNameForSelector:(SEL)sel
{
	if (sel == @selector(replace:withElementName:elementClass:elementID:text:innerSpan:innerParagraph:))
	{
		return @"replaceElement";
	}
	if (sel == @selector(replace:withText:))
	{
		return @"replaceText";
	}
	return @""; // [NSStringFromSelector(sel) stringByReplacing:@":" with:@"_"];
}


#if 0
/*!	Ask the target for its method signature
*/
-(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature *result = [super methodSignatureForSelector:aSelector];
	if (nil == result)
	{
		result = [myTarget methodSignatureForSelector:aSelector];
	}
	return result;
}

-(void)forwardInvocation:(NSInvocation *)anInvocation
{
	if (nil != anInvocation)
	{
		[anInvocation invokeWithTarget:myTarget];
	}
}
#endif

@end
