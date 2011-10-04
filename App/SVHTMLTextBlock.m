//
//  KTWebViewTextBlock.m
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//


#import "SVHTMLTextBlock.h"
#import "SVHTMLTemplateParser+Private.h"

#import "KTDesign.h"
#import "SVHTMLContext.h"
#import "SVImageReplacementURLProtocol.h"
#import "KTMaster.h"
#import "KTPage+Internal.h"
#import "SVRichText.h"
#import "SVTextContentHTMLContext.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"

#import "KSSHA1Stream.h"
#import "NSObject+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSCSSWriter.h"
#import "KSURLUtilities.h"

#import "Debug.h"
#import "Macros.h"



#define HTML_VALUE [[self HTMLSourceObject] valueForKeyPath:[self HTMLSourceKeyPath]]


@implementation SVHTMLTextBlock

#pragma mark Init & Dealloc

- (id)init
{
    self = [super init];
    
    if (self)
    {
        myIsEditable = YES;
        _alignment = NSNaturalTextAlignment;
        [self setTagName:@"div"];
    }
	
	return self;
}

- (void)dealloc
{
    [_placeholder release];
	[myHTMLTag release];
    [_className release];
    [_id release];
	[myHyperlinkString release];
	[myTargetString release];
	[myHTMLSourceObject release];
	[myHTMLSourceKeyPath release];
    
	[super dealloc];
}

#pragma mark Accessors

@synthesize placeholderString = _placeholder;

@synthesize tagName = myHTMLTag;
- (void)setTagName:(NSString *)tag
{
	OBPRECONDITION(tag);
	
	tag = [tag copy];
	[myHTMLTag release];
	myHTMLTag = tag;
}

@synthesize customCSSClassName = _className;
@synthesize customCSSID = _id;

- (void)buildClassName:(SVHTMLContext *)context;
{
    // Any custom classname specifed
    NSString *customClass = [self customCSSClassName];
    if ([customClass length]) [context pushClassName:customClass];
    
    
    // Editing
    if ([self isEditable])
    {
        if ([context isForEditing])
        { 
            [context pushClassName:([self isRichText] ? @"kBlock" : @"kLine")];
        }
    }
    else
    {
        [context pushClassName:@"in"];
    }
}

@synthesize hyperlinkString = myHyperlinkString;

- (void)setHyperlinkString:(NSString *)hyperlinkString
{
	// We can't have a hyperlinkString and be editable at the same time
	if ([self isEditable]) [self setEditable:NO];
	
	hyperlinkString = [hyperlinkString copy];
	[myHyperlinkString release];
	myHyperlinkString = hyperlinkString;
}

- (NSString *)targetString { return myTargetString; }

- (void)setTargetString:(NSString *)targetString
{
	targetString = [targetString copy];
	[myTargetString release];
	myTargetString = targetString;
}


- (id)HTMLSourceObject { return myHTMLSourceObject; }

- (void)setHTMLSourceObject:(id)object
{
	[object retain];
	[myHTMLSourceObject release];
	myHTMLSourceObject = object;
}

- (NSString *)HTMLSourceKeyPath { return myHTMLSourceKeyPath; }

- (void)setHTMLSourceKeyPath:(NSString *)keyPath
{
	keyPath = [keyPath copy];
	[myHTMLSourceKeyPath release];
	myHTMLSourceKeyPath = keyPath;
}

#pragma mark NSTextView clone

- (BOOL)isEditable { return myIsEditable; }
- (void)setEditable:(BOOL)flag { myIsEditable = flag; }

- (BOOL)isFieldEditor { return myIsFieldEditor; }
- (void)setFieldEditor:(BOOL)flag { myIsFieldEditor = flag; }

- (BOOL)isRichText { return myIsRichText; }
- (void)setRichText:(BOOL)flag { myIsRichText = flag; }

- (BOOL)importsGraphics { return myImportsGraphics; }
- (void)setImportsGraphics:(BOOL)flag { myImportsGraphics = flag; }

@synthesize alignment = _alignment;

#pragma mark Graphical Text

- (NSString *)graphicalTextCode:(SVHTMLContext *)context;
{
    NSString *result = nil;
    
    id value = HTML_VALUE;
    if ([value isKindOfClass:[SVTitleBox class]])
    {
        result = [value graphicalTextCode:context];
    }
    
    return result;
}

- (NSString *)graphicalTextStyleWithImageURLString:(NSString *)url
                                       width:(unsigned)width
                                      height:(unsigned)height;
{
    NSString *result = [NSString stringWithFormat:
                        @"text-align:left; text-indent:-9999px; background:url(\"%@\") top left no-repeat !important; width:%upx; height:%upx;",
                        url,   // quotes are needed around the URL in case it contains an apostrophe. #120419
                        width,
                        height];
    
    return result;
}

- (void)buildGraphicalText:(SVHTMLContext *)context;
{
    // Bail early if possible
    KTPage *page = [context page];
    KTMaster *master = [page master];
    if (![[master enableImageReplacement] boolValue]) return;
    
    NSString *graphicalTextCode = [self graphicalTextCode:context];
    if (!graphicalTextCode) return;
    
    
    
    // What's the special URL to build the image?
    KTDesign *design = [master design];
    
    NSDictionary *graphicalTextSettings = [[design imageReplacementTags] objectForKey:graphicalTextCode];
    if (!graphicalTextSettings) return;
    
    [design loadLocalFontsIfNeeded];    // #102950
    
    NSURL *compositionURL = [design URLForCompositionForImageReplacementCode:graphicalTextCode];
    if (!compositionURL) return;
    
    NSString *text = [(SVTitleBox *)HTML_VALUE text];
    
    NSURL *url = [NSURL imageReplacementURLWithRendererURL:compositionURL
                                                    string:text
                                                      size:[master graphicalTitleSize]];
    OBASSERT(url);

    
    
    // Load the image to learn size info
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
    if (!data) return;
    
    CIImage *image = [[CIImage alloc] initWithData:data];
    if (!image) return;
    
    unsigned width = [image extent].size.width;
    unsigned height = [image extent].size.height;
    [image release];
    
    
    
    // Apply the style
    if ([context isForPublishing])
    {
        // Register with context
        NSString *ID = [NSString stringWithFormat:
                        @"%@-%@",
                        graphicalTextCode,
                        [[text dataUsingEncoding:NSUTF8StringEncoding] ks_SHA1DigestString]];
        
        url = [context addGraphicalTextData:data idName:ID];
        NSString *urlString = [url ks_stringRelativeToURL:[context mainCSSURL]];
        
        
        // Build proper CSS rule
        NSMutableString *css = [[NSMutableString alloc] init];
        KSCSSWriter *cssWriter = [[KSCSSWriter alloc] initWithOutputWriter:css];
        
        [context pushAttribute:@"id" value:ID];
        
        [cssWriter writeIDSelector:ID];
        
        [cssWriter writeDeclarationBlock:[self graphicalTextStyleWithImageURLString:urlString
                                                                        width:width
                                                                       height:height]];
        
        [context addCSSString:css];
        [css release];
        [cssWriter release];
    }
    else
    {
        NSString *cssText = [self graphicalTextStyleWithImageURLString:[url absoluteString] width:width height:height];
        [context pushAttribute:@"style" value:cssText];
    }
    
    [context addDependencyOnObject:[context page] keyPath:@"master.graphicalTitleSize"];
    
    
    // Graphical text
    [context pushClassName:@"replaced"];
}

#pragma mark HTML

/*	Includes the editable tag(s) + innerHTML
 */
- (void)writeHTML:(SVHTMLContext *)context;
{
    [context willBeginWritingHTMLTextBlock:self];
    
	
    
	[self startElements:context];
    
	
	// Stick in the main HTML
	if ([self isRichText])
    {
        [context startNewline];
        [context stopWritingInline];
    }
    [self writeInnerHTML:context];
	
	
	// Write end tags
	[self endElements:context];
    
    
    [context didEndWritingHTMLTextBlock];
}

- (void)writeInnerHTML:(SVHTMLContext *)context;
{
    NSString *result = HTML_VALUE;
    if ([result isKindOfClass:[SVRichText class]])
    {
        [(SVRichText *)result writeText:context];
    }
    else if ([result isKindOfClass:[SVTitleBox class]])
    {
        NSString *text = [(SVTitleBox *)result textHTMLString];
        if (![text length]) text = [self placeholderString];
        if (!text) text = NSLocalizedString(@"Title", "placeholder");   // I really ought to use -placeholderString!
        
        NSAttributedString *html = [[NSAttributedString alloc] initWithString:text];
        [context writeAttributedHTMLString:html];
        [html release];
    }
    else
    {
        result = [self processHTML:result context:context];
        if (result) [context writeHTMLString:result];
    }
}

- (void)startElements:(SVHTMLContext *)context;
{
    // Build up id & class
    if ([self customCSSID]) [context pushAttribute:@"id" value:[self customCSSID]];
    [self buildClassName:context];
    
    
    // Add in graphical text styling if there is any
	if ([context includeStyling])
	{
		[self buildGraphicalText:context];
    }
    
    
    // Alignment
    switch ([self alignment])
    {
        case NSLeftTextAlignment:
            [context pushAttribute:@"style" value:@"text-align:left;"];
            break;
        case NSCenterTextAlignment:
            [context pushAttribute:@"style" value:@"text-align:center;"];
            break;
        case NSRightTextAlignment:
            [context pushAttribute:@"style" value:@"text-align:right;"];
            break;
        default:
            break;
    }
    
    
	// Main tag
    NSString *element = [self tagName];
    if ([element isEqualToStringCaseInsensitive:@"h"])
    {
        [context startHeadingWithAttributes:nil];
    }
    else
    {
        [context startElement:element];
    }
	
    
	    
	
	// Place a hyperlink if required
	if ([self hyperlinkString])
	{
        [context startAnchorElementWithHref:[self hyperlinkString]
                                      title:nil
                                     target:[self targetString]
                                        rel:nil];
	}
	
	
	// Generate <span class="in"> if desired
	BOOL generateSpanIn = [self generateSpanIn];
	if (generateSpanIn)	// For normal, single-line text the span is the editable bit
	{
        [context startElement:@"span" idName:nil className:@"in"];
	}
}

- (void)endElements:(SVHTMLContext *)context;
{
    if ([self generateSpanIn]) [context endElement];
	if ([self hyperlinkString]) [context endElement];
	[context endElement];
}

- (BOOL)generateSpanIn;
{
    return ([self isFieldEditor] && 
            ![[self tagName] isEqualToString:@"span"] &&
            ![HTML_VALUE isKindOfClass:[SVRichText class]]);    // hack to stop footer generating it
}


/*  Support method that takes a block of HTML and applies to it anything special the receiver and the parser require
 */
- (NSString *)processHTML:(NSString *)result context:(SVHTMLContext *)context;
{
    return result;
}

#pragma mark DOM Controller

- (SVDOMController *)newDOMController;
{    
    // Use the right sort of text area
    id value = HTML_VALUE;
    
    if ([value respondsToSelector:@selector(newTextDOMController)])
    {
        // Copy basic properties from text block
        SVTextDOMController *controller = [value newTextDOMController];
        [controller setTextBlock:self];
        return controller;
    }
    
    
    // Copy basic properties from text block
    SVTextFieldDOMController *result = [[SVTextFieldDOMController alloc] init];
    [result setTextBlock:self];
    [result setEditable:[self isEditable]];
    [result setRichText:[self isRichText]];
    [result setFieldEditor:[self isFieldEditor]];
    if (![self isFieldEditor]) [result setPlaceholderHTMLString:@"<p><br /></p>"];
    
    // Bind to model
    if ([self HTMLSourceObject] && [self HTMLSourceKeyPath])
    {
        [result bind:NSValueBinding
            toObject:[self HTMLSourceObject]
         withKeyPath:[self HTMLSourceKeyPath]
             options:nil];
    }
    
    return result;
}

@end
