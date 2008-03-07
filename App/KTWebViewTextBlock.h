//
//  KTWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTDocWebViewController;


@interface KTWebViewTextBlock : NSObject
{
	@private
	
	NSString		*myDOMNodeID;
	DOMHTMLElement	*myDOMNode;
	
	BOOL		myIsFieldEditor;
	BOOL		myIsRichText;
	BOOL		myImportsGraphics;
	BOOL		myHasSpanIn;
	NSString	*myHTMLTag;
	
	id			myHTMLSourceObject;
	NSString	*myHTMLSourceKeyPath;
		
	BOOL	myIsEditing;
}

+ (KTWebViewTextBlock *)textBlockForDOMNode:(DOMNode *)node
								  webViewController:(KTDocWebViewController *)webViewController;


#pragma mark Accessors

// PRIVATE method. Designated initialiser.
- (id)initWithDOMNodeID:(NSString *)ID;

- (NSString *)DOMNodeID;
- (DOMHTMLElement *)DOMNode;

- (BOOL)isFieldEditor;
- (void)setFieldEditor:(BOOL)flag;
- (BOOL)isRichText;
- (void)setRichText:(BOOL)flag;
- (BOOL)importsGraphics;
- (void)setImportsGraphics:(BOOL)flag;
- (BOOL)hasSpanIn;
- (void)setHasSpanIn:(BOOL)flag;

- (NSString *)HTMLTag;
- (void)setHTMLTag:(NSString *)tag;

- (id)HTMLSourceObject;
- (void)setHTMLSourceObject:(id)object;
- (NSString *)HTMLSourceKeyPath;
- (void)setHTMLSourceKeyPath:(NSString *)keyPath;

//- (KTDocWebViewController *)webViewController;

#pragma mark Editing

- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (BOOL)commitEditing;


@end
