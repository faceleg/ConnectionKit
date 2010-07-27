//
//  KTWebViewTextBlock.m
//  Marvel
//
//  Created by Mike on 19/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//


#import "SVHTMLTextBlock.h"
#import "SVHTMLTemplateParser+Private.h"

#import "KTDesign.h"
#import "KTMaster.h"
#import "KTAbstractPage+Internal.h"
#import "SVImageReplacementURLProtocol.h"
#import "KTPage+Internal.h"
#import "SVRichText.h"
#import "SVTextContentHTMLContext.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"
#import "SVWebEditorHTMLContext.h"

#import "NSObject+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSCSSWriter.h"

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
        [self setTagName:@"div"];
    }
	
	return self;
}

- (void)dealloc
{
    [_placeholder release];
	[myHTMLTag release];
    [_className release];
	[myHyperlinkString release];
	[myTargetString release];
	[myHTMLSourceObject release];
	[myHTMLSourceKeyPath release];
    
	[super dealloc];
}

#pragma mark Accessors

- (NSString *)elementIdName
{
    id value = HTML_VALUE;
	if ([value isKindOfClass:[SVContentObject class]])
    {
        return [value elementIdName];
    }
    else
    {
        NSString *result = [NSString stringWithFormat:@"k-svxTextBlock-%@-%p",
                            [self HTMLSourceKeyPath],
                            [self HTMLSourceObject]];
        
        return result;
    }
}

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

- (void)writeClassNames:(SVHTMLContext *)context;
{
    // Any custom classname specifed
    NSString *customClass = [self customCSSClassName];
    if ([customClass length]) [context addClassName:customClass];
    
    
    // Editing
    if ([self isEditable])
    {
        if ([context isForEditing])
        { 
            [context addClassName:([self isRichText] ? @"kBlock" : @"kLine")];
        }
    }
    else
    {
        [context addClassName:@"in"];
    }
    
    
    // Graphical text
    if ([self graphicalTextPreviewStyle:context]) [context addClassName:@"replaced"];
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

- (NSURL *)graphicalTextImageURL:(SVHTMLContext *)context;
{
    NSURL *result = nil;
	
    
    NSString *graphicalTextCode = [self graphicalTextCode:context];
    if (graphicalTextCode)
    {    
        KTPage *page = [context page];
        KTMaster *master = [page master];
        KTDesign *design = [master design];
        
        NSDictionary *graphicalTextSettings = [[design imageReplacementTags] objectForKey:graphicalTextCode];
        
        if (graphicalTextSettings)
        {
            NSURL *composition = [design URLForCompositionForImageReplacementCode:graphicalTextCode];
            NSString *string = [(SVTitleBox *)HTML_VALUE text];
            
            result = [NSURL imageReplacementURLWithRendererURL:composition
                                                        string:string
                                                          size:[master graphicalTitleSize]];
        }
    }
    
	
	return result;
}

- (NSString *)graphicalTextCSSID:(SVHTMLContext *)context
{
    NSString *result = nil;
    
    if ([self graphicalTextCode:context])
    {
        NSMutableString *innerText = [[NSMutableString alloc] init];
        SVHTMLContext *context = [[SVTextContentHTMLContext alloc] initWithOutputWriter:innerText];
        
        [self writeInnerHTML:context];
        [context close]; [context release];
        
        result = [NSString stringWithFormat:
                  @"%@-%@",
                  [self graphicalTextCode:context],
                  [innerText stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
        [innerText release];
    }
    
    return result;
}

/*	Returns nil if there is no graphical text in use
 */
- (NSString *)graphicalTextPreviewStyle:(SVHTMLContext *)context;
{
	NSString *result = nil;
	
	    
    if ([[[[context page] master] enableImageReplacement] boolValue])
    {
        NSURL *url = [self graphicalTextImageURL:context];
        if (url)
        {
            NSURLRequest *request = [NSURLRequest requestWithURL:url];
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
            if (data)
            {
                CIImage *image = [[CIImage alloc] initWithData:data];
                if (image)
                {
                    unsigned int width = [image extent].size.width;
                    unsigned int height = [image extent].size.height;
                    
                    result = [NSString stringWithFormat:
                              @"text-align:left; text-indent:-9999px; background:url(%@) top left no-repeat; width:%upx; height:%upx;",
                              [url absoluteString],
                              width,
                              height];
                    
                    [image release];
                }
            }
        }
    }
    
	
	return result;
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
        NSString *html = [(SVTitleBox *)result textHTMLString];
        if (html) [context writeHTMLString:html];
    }
    else
    {
        result = [self processHTML:result context:context];
        if (result) [context writeHTMLString:result];
    }
}

- (void)startElements:(SVHTMLContext *)context;
{
    // Build up class
    [self writeClassNames:context];
    
    
    // in some situations we generate both the main tag, and a <span class="in">
    if ([context isForEditing])
    {
        NSString *elementID = [self elementIdName];
        if (elementID) [context addElementAttribute:@"id" value:elementID];
    }
    
    
    // Add in graphical text styling if there is any
	if ([context includeStyling])
	{
		NSString *graphicalTextStyle = [self graphicalTextPreviewStyle:context];
		if (graphicalTextStyle)
		{
			if ([context isForPublishing])    // id has already been supplied
			{
                NSMutableString *css = [[NSMutableString alloc] init];
                KSCSSWriter *cssWriter = [[KSCSSWriter alloc] initWithOutputWriter:css];
                
                NSString *ID = [self graphicalTextCSSID:context];
                [context addElementAttribute:@"id" value:ID];
                [cssWriter writeIDSelector:ID];
                
                [cssWriter writeDeclarationBlock:graphicalTextStyle];
                
                [context addCSSString:css];
                [css release];
                [cssWriter release];
			}
			else
			{
                [context addElementAttribute:@"style" value:graphicalTextStyle];
			}
		}
	}
    
    [context addDependencyOnObject:[context page] keyPath:@"master.graphicalTitleSize"];
    
	// Main tag
	[context startElement:[self tagName]];
	
    
	    
	
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

/*!	Given the page text, scan for all page ID references and convert to the proper relative links.
 */
- (NSString *)fixPageLinksFromString:(NSString *)originalString context:(SVHTMLContext *)context;
{
	NSMutableString *buffer = [NSMutableString string];
	if (originalString)
	{
		NSScanner *scanner = [NSScanner scannerWithString:originalString];
		while (![scanner isAtEnd])
		{
			NSString *beforeLink = nil;
			BOOL found = [scanner scanUpToString:kKTPageIDDesignator intoString:&beforeLink];
			if (found)
			{
				[buffer appendString:beforeLink];
				if (![scanner isAtEnd])
				{
					[scanner scanString:kKTPageIDDesignator intoString:nil];
					NSString *idString = nil;
					BOOL foundNumber = [scanner scanCharactersFromSet:[KTAbstractPage uniqueIDCharacters]
														   intoString:&idString];
					if (foundNumber)
					{
						KTPage *thePage = [KTPage pageWithUniqueID:idString inManagedObjectContext:[[self HTMLSourceObject] managedObjectContext]];
						NSString *newPath = nil;
						if (thePage)
						{
							newPath = [context relativeURLStringOfPage:thePage];
						}
						
						if (!newPath) newPath = @"#";	// Fallback
						[buffer appendString:newPath];
					}
				}
			}
		}
	}
	return [NSString stringWithString:buffer];
}

- (BOOL)generateSpanIn;
{
    return ([self isFieldEditor] && 
            ![[self tagName] isEqualToString:@"span"]);
}


/*  Support method that takes a block of HTML and applies to it anything special the receiver and the parser require
 */
- (NSString *)processHTML:(NSString *)result context:(SVHTMLContext *)context;
{
    // Perform additional processing of the text according to HTML generation purpose
	if (![context isForEditing])
	{
		// Fix page links
		result = [self fixPageLinksFromString:result context:context];
	}
    
    
    
    return result;
}

#pragma mark DOM Controller

- (SVDOMController *)newDOMController;
{    
    // Use the right sort of text area
    id value = HTML_VALUE;
    
    if ([value isKindOfClass:[SVContentObject class]])
    {
        // Copy basic properties from text block
        SVDOMController *controller = [value newDOMController];
        [(SVTextDOMController *)controller setTextBlock:self];
        return controller;
    }
    
    
    // Copy basic properties from text block
    SVTextDOMController *result = [[SVTextFieldDOMController alloc] initWithElementIdName:[self elementIdName]];
    [result setTextBlock:self];
    [result setEditable:[self isEditable]];
    [result setRichText:[self isRichText]];
    [result setFieldEditor:[self isFieldEditor]];
    
    // Bind to model
    [result bind:NSValueBinding
        toObject:[self HTMLSourceObject]
     withKeyPath:[self HTMLSourceKeyPath]
         options:nil];
    
    
    return result;
}

@end
