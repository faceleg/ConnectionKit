//
//  SVMigrationHTMLWriterDOMAdaptor.m
//  Sandvox
//
//  Created by Mike on 24/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMigrationHTMLWriterDOMAdaptor.h"

#import "SVArticleDOMController.h"
#import "SVGraphicFactory.h"
#import "SVRawHTMLGraphic.h"


@implementation SVMigrationHTMLWriterDOMAdaptor

- (BOOL)DOMElementContainsAWebEditorItem:(DOMElement *)element;
{
    NSArray *items = [[self articleDOMController] childWebEditorItems];
    for (WEKWebEditorItem *anItem in items)
    {
        if ([[anItem HTMLElement] ks_isDescendantOfElement:element]) return YES;
    }
    
    return NO;
}

- (DOMNode *)handleInvalidDOMElement:(DOMElement *)element;
{
    if ([self DOMElementContainsAWebEditorItem:element])    // can't be converted to raw HTML
    {
        return [super handleInvalidDOMElement:element];
    }
    else
    {
        // Import as Raw HTML
        NSString *html = [KSXMLWriterDOMAdaptor outerHTMLOfDOMElement:element];
        
        SVRawHTMLGraphic *graphic = [[SVGraphicFactory rawHTMLFactory] insertNewGraphicInManagedObjectContext:
                                     [[[self articleDOMController] representedObject] managedObjectContext]];
        
        [graphic setHTMLString:html];
        
        
        // Create controller for graphic and hook up to imported node
        SVDOMController *controller = [graphic newDOMController];
        [controller awakeFromHTMLContext:[[self articleDOMController] HTMLContext]];
        [controller setHTMLElement:(DOMHTMLElement *)element];
        
        [[self articleDOMController] addChildWebEditorItem:controller];
        OBASSERT([[self articleDOMController] hitTestDOMNode:element] == controller);
        [controller release];
        
        
        // Generate new DOM node to match what model would normally generate
        [controller performSelector:@selector(update)];
        
        
        // Write the replacement
        [controller writeAttributedHTML:self];
        
        
        return [[controller HTMLElement] nextSibling];
    }
}

@synthesize articleDOMController = _articleController;

@end
