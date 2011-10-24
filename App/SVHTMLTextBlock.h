//
//  KTWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVComponent.h"

#import "KTDocument.h"


@class SVHTMLContext, SVDOMController, SVTextDOMController;


@interface SVHTMLTextBlock : NSObject <SVComponent>
{
//@private
	BOOL			myIsEditable;
	BOOL			myIsFieldEditor;
	BOOL			myIsRichText;
    NSString        *_placeholder;
	BOOL			myImportsGraphics;
    NSTextAlignment _alignment;
	
    NSString		*myHTMLTag;
    NSString        *_className;
    NSString        *_id;
	
	NSString		*myHyperlinkString;
	NSString		*myTargetString;
	
	id			myHTMLSourceObject;
	NSString	*myHTMLSourceKeyPath;
}

#pragma mark Accessors

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
@property(nonatomic) NSTextAlignment alignment;

//  Like .editable, has no effect on the HTML generated. But when editing, UI code will check the value to see if a custom string has been requested
@property(nonatomic, copy) NSString *placeholderString;

@property(nonatomic, copy) NSString *tagName;
@property(nonatomic, copy) NSString *customCSSClassName;
@property(nonatomic, copy) NSString *customCSSID;


@property(nonatomic, copy) NSString *hyperlinkString;

- (NSString *)targetString;
- (void)setTargetString:(NSString *)targetString;

@property(nonatomic, retain) id HTMLSourceObject;
@property(nonatomic, copy) NSString *HTMLSourceKeyPath;

- (void)buildGraphicalText:(SVHTMLContext *)context;


#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
- (void)writeInnerHTML:(SVHTMLContext *)context;
- (void)startElements:(SVHTMLContext *)context;
- (void)endElements:(SVHTMLContext *)context;

- (BOOL)generateSpanIn;
- (NSString *)processHTML:(NSString *)originalHTML context:(SVHTMLContext *)context;


@end


@interface NSObject (SVHTMLTextBlock)
- (SVTextDOMController *)newTextDOMControllerWithIdName:(NSString *)elementID ancestorNode:(DOMNode *)document;
@end

