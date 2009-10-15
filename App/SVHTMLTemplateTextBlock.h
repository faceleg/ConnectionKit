//
//  KTWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTDocument.h"


@class KTDocWebViewController, KTWebViewComponent, KTMediaContainer, KTAbstractPage, SVHTMLTemplateParser;


@interface SVHTMLTemplateTextBlock : NSObject
{
//@private
	SVHTMLTemplateParser		*myParser;    
	
	BOOL			myIsEditable;
	BOOL			myIsFieldEditor;
	BOOL			myIsRichText;
	BOOL			myImportsGraphics;
	BOOL			myHasSpanIn;
	NSString		*myHTMLTag;
	NSString		*myGraphicalTextCode;
	NSString		*myHyperlinkString;
	NSString		*myTargetString;
	
	id			myHTMLSourceObject;
	NSString	*myHTMLSourceKeyPath;
}

#pragma mark Accessors

- (id)initWithParser:(SVHTMLTemplateParser *)parser;
@property(nonatomic, retain, readonly) SVHTMLTemplateParser *parser;

@property(nonatomic, readonly) NSString *DOMNodeID;

@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, setter=setRichText:) BOOL isRichText;
@property(nonatomic, setter=setFieldEditor:) BOOL isFieldEditor;

- (BOOL)importsGraphics;
- (void)setImportsGraphics:(BOOL)flag;
- (BOOL)hasSpanIn;
- (void)setHasSpanIn:(BOOL)flag;

- (NSString *)HTMLTag;
- (void)setHTMLTag:(NSString *)tag;

- (NSString *)hyperlinkString;
- (void)setHyperlinkString:(NSString *)hyperlinkString;

- (NSString *)targetString;
- (void)setTargetString:(NSString *)targetString;

@property(nonatomic, retain) id HTMLSourceObject;
@property(nonatomic, copy) NSString *HTMLSourceKeyPath;

- (NSString *)graphicalTextCode;
- (void)setGraphicalTextCode:(NSString *)code;
- (KTMediaContainer *)graphicalTextMedia;
- (NSString *)graphicalTextCSSID;

#pragma mark HTML
- (NSString *)innerHTML;
- (NSString *)outerHTML;

- (NSString *)processHTML:(NSString *)originalHTML;

@end
