//
//  SVGraphicDOMController.m
//  Sandvox
//
//  Created by Mike on 23/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVGraphicDOMController.h"
#import "SVGraphic.h"

#import "SVRichTextDOMController.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "WebEditingKit.h"
#import "WebViewEditingHelperClasses.h"

#import "DOMNode+Karelia.h"


@interface SVGraphicPlaceholderDOMController : SVGraphicDOMController
@end


#pragma mark -


@interface DOMElement (SVGraphicDOMController)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@implementation SVGraphicDOMController

- (void)dealloc;
{
    [self setBodyHTMLElement:nil];
    OBPOSTCONDITION(!_bodyElement);
 
    [_replacmentDOMController release];     // should be nil unless
    [_offscreenWebViewController release];  // dealloc-ing mid-update
    
    [super dealloc];
}

#pragma mark Factory

+ (SVGraphicDOMController *)graphicPlaceholderDOMController;
{
    SVGraphicDOMController *result = [[[SVGraphicPlaceholderDOMController alloc] init] autorelease];
    return result;
}

+ (id)DOMControllerWithGraphic:(SVGraphic *)graphic
       parentWebEditorItemToBe:(SVDOMController *)parentItem;
{
    OBPRECONDITION(parentItem);
    
    
    // Write HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithOutputWriter:htmlString];
    
    SVWebEditorHTMLContext *parentContext = [parentItem HTMLContext];
    [context copyPropertiesFromContext:parentContext];
    [context setWebEditorViewController:[parentContext webEditorViewController]];   // hacky
    [context writeGraphic:graphic];
    
    
    // Retrieve controller
    id result = [[[context rootDOMController] childWebEditorItems] lastObject];
    OBASSERT(result);
    
    
    // Copy top-level dependencies across to parent. #79396
    for (KSObjectKeyPathPair *aDependency in [[context rootDOMController] dependencies])
    {
        [parentItem addDependency:aDependency];
    }
    
    [context release];
    
    
    // Create DOM objects from HTML
    DOMHTMLDocument *doc = (DOMHTMLDocument *)[[parentItem HTMLElement] ownerDocument];
    
    DOMDocumentFragment *fragment = [doc createDocumentFragmentWithMarkupString:htmlString
                                                                        baseURL:[parentContext baseURL]];
    [htmlString release];
    
    DOMHTMLElement *element = [fragment firstChildOfClass:[DOMHTMLElement class]];  OBASSERT(element);
    [result setHTMLElement:element];
    
    
    return result;
}

#pragma mark DOM

@synthesize bodyHTMLElement = _bodyElement;

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    [super loadHTMLElementFromDocument:document];
    
    // Locate body element too
    SVGraphic *graphic = [self representedObject];
    if ([graphic isPagelet])
    {
        DOMNodeList *elements = [[self HTMLElement] getElementsByClassName:@"pagelet-body"];
        [self setBodyHTMLElement:(DOMHTMLElement *)[elements item:0]];
    }
    else
    {
        [self setBodyHTMLElement:[self HTMLElement]];
    }
}

- (void)update;
{
    // Write HTML
    NSMutableString *htmlString = [[NSMutableString alloc] init];
    
    SVWebEditorHTMLContext *context = [[[SVWebEditorHTMLContext class] alloc]
                                       initWithOutputWriter:htmlString];
    
    [context copyPropertiesFromContext:[self HTMLContext]];
    [context setWebEditorViewController:[[self HTMLContext] webEditorViewController]];   // hacky
    [context writeGraphic:[self representedObject]];
    
    
    // Retrieve controller
    OBASSERT(!_replacmentDOMController);
    _replacmentDOMController = [[[context rootDOMController] childWebEditorItems] lastObject];
    [_replacmentDOMController retain];
    OBASSERT(_replacmentDOMController);
    
    
    // Copy top-level dependencies across to parent. #79396
    for (KSObjectKeyPathPair *aDependency in [[context rootDOMController] dependencies])
    {
        [(SVDOMController *)[self parentWebEditorItem] addDependency:aDependency];
    }
    
    [context release];
    
    
    // Start loading DOM objects from HTML
    OBASSERT(!_offscreenWebViewController);
    _offscreenWebViewController = [[SVOffscreenWebViewController alloc] init];
    [_offscreenWebViewController setDelegate:self];
    
    [_offscreenWebViewController loadHTMLFragment:htmlString];
    [htmlString release];
}

- (void)bodyLoaded:(DOMHTMLElement *)loadedBody;
{
    // Pull the nodes across to the Web Editor
    DOMDocument *document = [[self HTMLElement] ownerDocument];
    DOMNode *imported = [document importNode:[loadedBody firstChild] deep:YES];
	
    
    // I have to turn off the script nodes from actually executing
	DOMNodeIterator *it = [document createNodeIterator:imported whatToShow:DOM_SHOW_ELEMENT filter:[ScriptNodeFilter sharedFilter] expandEntityReferences:NO];
	DOMHTMLScriptElement *subNode;
    
	while ((subNode = (DOMHTMLScriptElement *)[it nextNode]))
	{
		[subNode setText:@""];		/// HACKS -- clear out the <script> tags so that scripts are not executed AGAIN
		[subNode setSrc:@""];
		[subNode setType:@""];
	}
    
    
    
    // Swap in result. Adding in the replacement DOM Controller will make View Controller hook it up to the right element etc.
    [[[self HTMLElement] parentNode] replaceChild:imported oldChild:[self HTMLElement]];
    [[self parentWebEditorItem] replaceChildWebEditorItem:self with:_replacmentDOMController];
    
    
    // Finish
    [self didUpdate];
    
    
    // Teardown
    [_offscreenWebViewController setDelegate:nil];
    [_offscreenWebViewController release]; _offscreenWebViewController = nil;
    [_replacmentDOMController release]; _replacmentDOMController = nil;
}

#pragma mark State

- (BOOL)isSelectable { return YES; }

- (void)setEditing:(BOOL)editing;
{
    [super setEditing:editing];
    
    
    // Make sure we're selectable while editing
    if (editing)
    {
        [[[self HTMLElement] style] setProperty:@"-webkit-user-select"
                                          value:@"auto"
                                       priority:@""];
    }
    else
    {
        [[[self HTMLElement] style] removeProperty:@"-webkit-user-select"];
    }
}

@end


#pragma mark -


@implementation SVGraphicPlaceholderDOMController

- (void)loadHTMLElementFromDocument:(DOMHTMLDocument *)document;
{
    DOMElement *element = [document createElement:@"DIV"];
    [[element style] setDisplay:@"none"];
    [self setHTMLElement:(DOMHTMLElement *)element];
}

@end



#pragma mark -


@implementation SVGraphic (SVDOMController)

- (SVDOMController *)newDOMController;
{
    return [[SVGraphicDOMController alloc] initWithRepresentedObject:self];
}

- (BOOL)shouldPublishEditingElementID { return NO; }
- (NSString *)elementIdName { return [self elementID]; }

@end
