// 
//  SVSidebar.m
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVSidebar.h"

#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "KTPage.h"
#import "SVSidebarPageletsController.h"
#import "SVTemplate.h"
#import "SVWebEditorHTMLContext.h"

#import "NSSortDescriptor+Karelia.h"


@implementation SVSidebar 

@dynamic page;

#pragma mark Pagelets

@dynamic pagelets;

- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error
{
    return [SVGraphic validateSortKeyForPagelets:pagelets error:error];
}

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context;
{
    [context beginGraphicContainer:self];
    [context startSidebar:self];
    
    {
        SVTemplate *template = [SVTemplate templateNamed:@"SidebarTemplate.html"];
        
        SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc]
                                        initWithTemplate:[template templateString]
                                        component:self];
        
        [parser parseIntoHTMLContext:context];
        [parser release];
    }
    
    [context writeEndTagWithComment:@"sidebar-container"];
    [context endGraphicContainer];
}

- (void)writeHTML; { [self writeHTML:[[SVHTMLTemplateParser currentTemplateParser] HTMLContext]]; }

- (void)writePageletsHTML:(SVHTMLContext *)context;
{
	NSUInteger savedHeaderLevel = [context currentHeaderLevel];	// probably don't need to save level, but we might as well
    [context setCurrentHeaderLevel:4];
    @try
    {
        // Use the best controller available to give us an ordered list of pagelets
        NSArrayController *controller = [context sidebarPageletsController];
        OBASSERT(controller);
        
        //[context addDependencyOnObject:controller keyPath:@"arrangedObjects"];    // taken care of by SVSidebarDOMController now
        
        
        // Write HTML
        [context writeGraphics:[controller arrangedObjects]];
    }
    @finally
    {
        [context setCurrentHeaderLevel:savedHeaderLevel];
    }
}

- (void)writePageletsHTML;
{
    [self writePageletsHTML:[[SVHTMLTemplateParser currentTemplateParser] HTMLContext]];
}

- (BOOL)shouldPublishEditingElementID; { return YES; }

@end
