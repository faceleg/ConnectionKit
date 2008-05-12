//
//  KTWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTDocument.h"


@class KTDocWebViewController, KTMediaContainer, KTAbstractPage, KTHTMLParser;


@interface KTWebViewTextBlock : NSObject
{
	@private
	
	NSString		*myDOMNodeID;
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
	KTPage		*myPage;
		
	BOOL	myIsEditing;
}

+ (KTWebViewTextBlock *)textBlockForDOMNode:(DOMNode *)node
						  webViewController:(KTDocWebViewController *)webViewController;


#pragma mark Accessors

// PRIVATE method. Designated initialiser.
- (id)initWithDOMNodeID:(NSString *)ID;

- (NSString *)DOMNodeID;
- (DOMHTMLElement *)DOMNode;

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

- (KTPage *)page;
- (void)setPage:(KTPage *)page;

- (NSString *)graphicalTextCode;
- (void)setGraphicalTextCode:(NSString *)code;
- (KTMediaContainer *)graphicalTextMedia;

#pragma mark HTML
- (NSString *)innerHTML:(KTHTMLParser *)parser;
- (NSString *)outerHTML:(KTHTMLParser *)parser;

#pragma mark Editing

- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (BOOL)commitEditing;


@end
