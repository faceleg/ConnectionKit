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
	[myGraphicalTextCode release];
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

- (NSString *)CSSClassName;
{
    NSMutableArray *classNames = [[NSMutableArray alloc] init];
    
    
    // Any custom classname specifed
    if ([[self customCSSClassName] length] > 0)
    {
        [classNames addObject:[self customCSSClassName]];
    }
    
    
    // Editing
    if ([self isEditable])
    {
        if ([[SVHTMLContext currentContext] isEditable])
        { 
            [classNames addObject:([self isRichText] ? @"kBlock" : @"kLine")];
        }
    }
    else
    {
        [classNames addObject:@"in"];
    }
    
    
    // Graphical text
    if ([self graphicalTextPreviewStyle]) [classNames addObject:@"replaced"];
    
    
    // Turn into a single string
    NSString *result = [classNames componentsJoinedByString:@" "];
    [classNames release];
    return result;
}

- (NSString *)hyperlinkString { return myHyperlinkString; }

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

/*	When the code is a non-nil value, if the design specifies it, we swap the text for special Quartz Composer
 *	generated images.
 */
- (NSString *)graphicalTextCode { return myGraphicalTextCode; }

- (void)setGraphicalTextCode:(NSString *)code
{
	code = [code copy];
	[myGraphicalTextCode release];
	myGraphicalTextCode = code;
}

- (NSURL *)graphicalTextImageURL;
{
    NSURL *result = nil;
	
    
    NSString *graphicalTextCode = [self graphicalTextCode];
    if (graphicalTextCode)
    {    
        KTPage *page = [[SVHTMLContext currentContext] page];
        KTMaster *master = [page master];
        if ([[master enableImageReplacement] boolValue])
        {
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
    }
    
	
	return result;
}

- (NSString *)graphicalTextCSSID
{
    NSString *result = nil;
    
    if ([self graphicalTextCode])
    {
        NSMutableString *innerText = [[NSMutableString alloc] init];
        SVHTMLContext *context = [[SVTextContentHTMLContext alloc] initWithOutputWriter:innerText];
        
        [self writeInnerHTML:context];
        [context close]; [context release];
        
        result = [NSString stringWithFormat:
                  @"%@-%@",
                  [self graphicalTextCode],
                  [innerText stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
        [innerText release];
    }
    
    return result;
}

/*	Returns nil if there is no graphical text in use
 */
- (NSString *)graphicalTextPreviewStyle
{
	NSString *result = nil;
	
	    
    NSURL *url = [self graphicalTextImageURL];
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
        result = [self processHTML:result];
        if (result) [context writeHTMLString:result];
    }
}

- (void)startElements:(SVHTMLContext *)context;
{
    // Main tag
	[context openTag:[self tagName]];
	
	// in some situations we generate both the main tag, and a <span class="in">
    NSString *elementID = [self elementIdName];
    if (elementID) [context writeAttribute:@"id" value:elementID];
    
    BOOL generateSpanIn = [self generateSpanIn];
	// if (!generateSpanIn)	// Actually we want a custom class to show up even items with a span-in. 
	{
		if (![[self CSSClassName] isEqualToString:@""])
		{
			[context writeAttribute:@"class" value:[self CSSClassName]];
		}
	}
	
	// TODO: Add in graphical text styling if there is any
	if ([context includeStyling])
	{
		NSString *graphicalTextStyle = [self graphicalTextPreviewStyle];
		if (graphicalTextStyle)
		{
			if ([[SVHTMLContext currentContext] isForPublishing])    // id has already been supplied
			{
                [context writeAttribute:@"id" value:[self graphicalTextCSSID]];
			}
			else
			{
                [context writeAttribute:@"style" value:graphicalTextStyle];
			}
		}
	}
	
	// Close off the main tag
	[context didStartElement];
    
	
	
	// Place a hyperlink if required
	if ([self hyperlinkString])
	{
		[context openTag:@"a"];
        [context writeString:@" "];
        [context writeString:[self targetString]];
        [context writeAttribute:@"href" value:[self hyperlinkString]];
        [context didStartElement];
	}
	
	
	// Generate <span class="in"> if desired
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
- (NSString *)fixPageLinksFromString:(NSString *)originalString
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
							newPath = [[thePage URL] stringRelativeToURL:[[SVHTMLContext currentContext] baseURL]];
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
- (NSString *)processHTML:(NSString *)result
{
    // Perform additional processing of the text according to HTML generation purpose
	if (![[SVHTMLContext currentContext] isEditable])
	{
		// Fix page links
		result = [self fixPageLinksFromString:result];
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
