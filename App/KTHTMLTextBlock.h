//
//  KTWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTDocument.h"


@class KTDocWebViewController, KTWebViewComponent, KTMediaContainer, KTAbstractPage, KTHTMLParser;


@interface KTHTMLTextBlock : NSObject
{
//@private
	KTHTMLParser		*myParser;
	KTWebViewComponent	*myWebViewComponent;	// Weak ref
    
	DOMHTMLElement	*myDOMNode;
	
	BOOL			myIsEditable;
	BOOL			myIsFieldEditor;
	BOOL			myIsRichText;
	BOOL			myImportsGraphics;
	BOOL			myHasSpanIn;
	NSString		*myHTMLTag;
	NSString		*myGraphicalTextCode;
	NSString		*myHyperlink;
	
	id			myHTMLSourceObject;
	NSString	*myHTMLSourceKeyPath;
		
	BOOL	myIsEditing;
}

#pragma mark Accessors

- (id)initWithParser:(KTHTMLParser *)parser;
- (KTHTMLParser *)parser;

- (KTWebViewComponent *)webViewComponent;
- (void)setWebViewComponent:(KTWebViewComponent *)component;

- (NSString *)DOMNodeID;
- (DOMHTMLElement *)DOMNode;
- (void)setDOMNode:(DOMHTMLElement *)node;


- (BOOL)isEditable;
- (void)setEditable:(BOOL)flag;
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

- (NSString *)hyperlink;
- (void)setHyperlink:(NSString *)hyperlink;

- (id)HTMLSourceObject;
- (void)setHTMLSourceObject:(id)object;
- (NSString *)HTMLSourceKeyPath;
- (void)setHTMLSourceKeyPath:(NSString *)keyPath;

- (NSString *)graphicalTextCode;
- (void)setGraphicalTextCode:(NSString *)code;
- (KTMediaContainer *)graphicalTextMedia;

#pragma mark HTML
- (NSString *)innerHTML;
- (NSString *)outerHTML;

- (NSString *)processHTML:(NSString *)originalHTML;

#pragma mark Editing

- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (BOOL)commitEditing;


@end
