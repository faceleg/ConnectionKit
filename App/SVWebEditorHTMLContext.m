//
//  SVWebEditorHTMLContext.m
//  Sandvox
//
//  Created by Mike on 05/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVWebEditorHTMLContext.h"

#import "SVApplicationController.h"
#import "SVCalloutDOMController.h"
#import "SVContentDOMController.h"
#import "SVHTMLTemplateParser.h"
#import "SVHTMLTextBlock.h"
#import "SVPlugInDOMController.h"
#import "SVMediaPlugIn.h"
#import "SVMediaRequest.h"
#import "SVIndexDOMController.h"
#import "KTPage.h"
#import "SVRichText.h"
#import "SVSidebarDOMController.h"
#import "SVSummaryDOMController.h"
#import "SVTemplateParser.h"
#import "SVTextBox.h"
#import "SVTextFieldDOMController.h"
#import "SVTitleBox.h"

#import "NSIndexPath+Karelia.h"
#import "KSObjectKeyPathPair.h"


@interface SVWebEditorHTMLContext ()
@end



#pragma mark -


@implementation SVWebEditorHTMLContext

#pragma mark Init & Dealloc

- (id)initWithOutputWriter:(id <KSWriter>)stream	// designated initializer
{
    [super initWithOutputWriter:stream];
    
    [self reset];
    _media = [[NSMutableSet alloc] init];
    _mediaByData = [[NSMutableDictionary alloc] init];
        
    return self;
}

#pragma mark Status

- (void)reset;
{
    [super reset];
    
    [_media removeAllObjects];
    [_mediaByData removeAllObjects];
}

- (void)close;
{
    [super close];
    
    // Ditch media
    [_media release]; _media = nil;
    [_mediaByData release]; _mediaByData = nil;
}

#pragma mark Page

- (void)writeDocumentWithPage:(KTPage *)page;
{
	// This is a dependency only in the Web Editor, so don't register for all contexts
    [self addDependencyOnObject:[NSUserDefaultsController sharedUserDefaultsController]
                        keyPath:[@"values." stringByAppendingString:kSVLiveDataFeedsKey]];

    [super writeDocumentWithPage:page];
}

#pragma mark Purpose

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeEditing; }

#pragma mark Metrics

- (void)XbuildAttributesForResizableElement:(NSString *)elementName object:(NSObject *)object DOMControllerClass:(Class)controllerClass sizeDelta:(NSSize)sizeDelta options:(SVResizingOptions)options;
{
    // Figure out a decent controller class
    if (!controllerClass) 
    {
        controllerClass = [SVPlugInDOMController class];
    }
    
    
    // 
    SVPlugInDOMController *controller = [[controllerClass alloc] initWithRepresentedObject:
                                              [[self currentDOMController] representedObject]];
    [controller setSizeDelta:sizeDelta];
    [controller setResizeOptions:options];
    
    
    // Has an ID for the controller already been decided?
    // TODO: Not sure this branch is even needed any more, look into ditching!
    if (![controller hasElementIdName])
    {
        KSXMLAttributes *info = [self currentAttributes];
        NSString *ID = [[info attributesAsDictionary] objectForKey:@"id"];
        if (ID)
        {
            [controller setElementIdName:ID includeWhenPublishing:YES];
        }
    }
    
    
    [self startDOMController:controller];
    [controller release];
    
    [super buildAttributesForResizableElement:elementName object:object DOMControllerClass:controllerClass sizeDelta:sizeDelta options:options];
}

#pragma mark Text Blocks

- (void)writeElement:(NSString *)elementName
     withTitleOfPage:(id <SVPage>)page
         asPlainText:(BOOL)plainText
          attributes:(NSDictionary *)attributes;
{
    // Create text-block
    SVHTMLTextBlock *textBlock = [[SVHTMLTextBlock alloc] init];
    [textBlock setEditable:NO];
    [textBlock setTagName:elementName];
    [textBlock setHTMLSourceObject:page];
    [textBlock setHTMLSourceKeyPath:@"title"];
    
    
    // Create controller
    [self willBeginWritingHTMLTextBlock:textBlock];
    [textBlock release];
    
    [super writeElement:elementName withTitleOfPage:page asPlainText:plainText attributes:attributes];

    
    [self didEndWritingHTMLTextBlock];
}

- (void)XwillWriteSummaryOfPage:(SVSiteItem *)page;
{
    // Generate DOM controller for it
    SVSummaryDOMController *controller = [[SVSummaryDOMController alloc] init];
    [controller setItemToSummarize:page];
    
    [self startDOMController:controller];
    [controller release];
    
    [super willWriteSummaryOfPage:page];
}

#pragma mark Resources

- (NSURL *)addResourceWithData:(NSData *)data
                      MIMEType:(NSString *)mimeType
              textEncodingName:(NSString *)encoding
                   destination:(NSString *)uploadPath
                       options:(NSUInteger)options;
{
    NSURL *result = [super addResourceWithData:data
                                      MIMEType:mimeType
                              textEncodingName:encoding
                                   destination:uploadPath
                                       options:options];
    
    // Make sure URL isn't relative
    result = [NSURL URLWithString:[result absoluteString]
                    relativeToURL:[NSURL URLWithString:@"http://example.com"]];
    result = [result absoluteURL];
    
    // Add to web resources
    SVMedia *media = [[SVMedia alloc] initWithData:data URL:result];
    return [self addMedia:media];
}

#pragma mark Dependencies

- (void)addDependency:(KSObjectKeyPathPair *)dependency;
{
    [super addDependency:dependency];
    
    // Ignore parser properties. And now context too
    // I think my original reason is that those properties aren't really going to change, but we're interested in depending on the original source of that property. e.g. reload when user turns on/off live data feeds, but do so with a fresh context
    if ([[dependency object] isKindOfClass:[SVTemplateParser class]] ||
        [[dependency keyPath] hasPrefix:@"currentContext."])
    {
        return;
    }
    
    
    //[[self currentDOMController] addDependency:dependency];
}

- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
{
    // Trying to observe next/previous page's title with a compound keypath is a bad idea. #102968
    if ([object isKindOfClass:[KTPage class]])
    {
        if ([keyPath hasPrefix:@"nextPage."])
        {
            object = [object valueForKey:@"nextPage"];
            keyPath = [keyPath substringFromIndex:[@"nextPage." length]];
        }
        else if ([keyPath hasPrefix:@"previousPage."])
        {
            object = [object valueForKey:@"previousPage"];
            keyPath = [keyPath substringFromIndex:[@"previousPage." length]];
        }
    }
    else if ([object isKindOfClass:[SVHTMLTemplateParser class]])
    {
        if ([keyPath hasPrefix:@"currentPage."])
        {
            object = [object valueForKey:@"currentPage"];
            keyPath = [keyPath substringFromIndex:[@"currentPage." length]];
        }
    }
    else if ([object isKindOfClass:[SVPlugIn class]])
    {
        if ([keyPath hasPrefix:@"currentContext."])
        {
            object = [object valueForKey:@"currentContext"];
            keyPath = [keyPath substringFromIndex:[@"currentContext." length]];
        }
    }
    
    
    
    [super addDependencyOnObject:object keyPath:keyPath];
}

#pragma mark Media

- (NSSet *)media; { return [[_media copy] autorelease]; }

- (NSURL *)addMediaWithRequest:(SVMediaRequest *)request;
{
    NSURL *result = nil;
    
    SVMedia *media = [request media];
    NSData *data = [media mediaData];
    
    if (data)
    {
        SVMedia *matchingMedia = [_mediaByData objectForKey:data];
        if (matchingMedia)
        {
            media = matchingMedia;
        }
        else
        {
            [_mediaByData setObject:media forKey:data];
        }
    }
    
    result = [super addMediaWithRequest:request];
    [_media addObject:media];
    
    return result;
}

#pragma mark Sidebar

- (void)XstartSidebar:(SVSidebar *)sidebar;
{
    // Create controller
    SVSidebarDOMController *controller = [[SVSidebarDOMController alloc]
                                          initWithPageletsController:[self sidebarPageletsController]];
    
    [controller setRepresentedObject:sidebar];
    
    // Store controller
    [self startDOMController:controller];    
    
    
    [super startSidebar:sidebar];
    
    // Finish up
    [controller release];
}

#pragma mark Element Primitives

- (void)startElement:(NSString *)elementName writeInline:(BOOL)writeInline; // for more control
{
    // First add an id attribute if it's needed
    // DOM Controllers need an ID so they can locate their element in the DOM. If the HTML doesn't normally contain an ID, insert it ourselves
    SVElementInfo *elementInfo = [self currentElement];
    if ([elementInfo component])
    {
        if (![[[self currentAttributes] attributesAsDictionary] objectForKey:@"id"])
        {
            // Invent an ID for the controller if needed
            NSString *idName = [NSString stringWithFormat:@"component-%p", elementInfo];
            [self pushPreferredIdName:idName];
            [elementInfo setElementIdNameWasInvented:YES];
        }
    }
    
    [super startElement:elementName writeInline:writeInline];
}

@end


#pragma mark -


@implementation SVHTMLContext (SVEditing)

- (void)startSidebar:(SVSidebar *)sidebar;
{
    [self startElement:@"div" idName:@"sidebar-container" className:nil];
}

@end



#pragma mark -


@implementation SVDOMController (SVWebEditorHTMLContext)

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context;
{
    [self setHTMLContext:context];
}

@end



#pragma mark -


@implementation WEKWebEditorItem (SVWebEditorHTMLContext)

- (void)awakeFromHTMLContext:(SVWebEditorHTMLContext *)context; { }

@end

