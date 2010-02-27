//
//  KTWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "KTDocument.h"


@protocol SVMedia;


@interface SVHTMLTextBlock : NSObject
{
//@private
	BOOL			myIsEditable;
	BOOL			myIsFieldEditor;
	BOOL			myIsRichText;
    NSString        *_placeholder;
	BOOL			myImportsGraphics;
	
    NSString		*myHTMLTag;
    NSString        *_className;
	BOOL			myHasSpanIn;
	
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

//  Like .editable, has no effect on the HTML generated. But when editing, UI code will check the value to see if a custom string has been requested
@property(nonatomic, copy) NSString *placeholderString;

@property(nonatomic, copy) NSString *tagName;
@property(nonatomic, copy) NSString *customCSSClassName;
- (NSString *)CSSClassName;
@property(nonatomic) BOOL hasSpanIn;


- (NSString *)hyperlinkString;
- (void)setHyperlinkString:(NSString *)hyperlinkString;

- (NSString *)targetString;
- (void)setTargetString:(NSString *)targetString;

@property(nonatomic, retain) id HTMLSourceObject;
@property(nonatomic, copy) NSString *HTMLSourceKeyPath;

- (NSString *)graphicalTextCode;
- (void)setGraphicalTextCode:(NSString *)code;
- (id <SVMedia>)graphicalTextMedia;
- (NSURL *)graphicalTextImageURL;
- (NSString *)graphicalTextCSSID;

#pragma mark HTML
- (void)writeInnerHTML;
- (void)writeHTML;

- (NSString *)processHTML:(NSString *)originalHTML;

@end
