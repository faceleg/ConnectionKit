//
//  KTWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTDocument.h"


@class KTMediaContainer;


@interface SVHTMLTextBlock : NSObject
{
//@private
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

@property(nonatomic, readonly) NSString *DOMNodeID;

//  Indicates if the template specifed the block as editable. Regardless of the value, text blocks NEVER generate HTML that includes:
//      contenteditable="true"
//  
//  Instead, whosever is loading the HTML into DOM is responsible for making the appropriate text editable afterwards. This is to:
//      a)  Reduce the difference between standard and editing HTML output
//      b)  Place responsibility for handling invalid HTML (such as from a Raw HTML plug-in) on the controller layer, not the model
//  
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
