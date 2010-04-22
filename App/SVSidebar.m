// 
//  SVSidebar.m
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSidebar.h"

#import "SVGraphic.h"
#import "SVHTMLTemplateParser.h"
#import "KTPage.h"
#import "SVSidebarPageletsController.h"
#import "SVWebEditorHTMLContext.h"

#import "NSSortDescriptor+Karelia.h"


@implementation SVSidebar 

@dynamic page;

#pragma mark Pagelets

@dynamic pagelets;

- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error
{
    return [SVGraphic validatePagelets:pagelets error:error];
}

#pragma mark HTML

- (void)writePageletsHTML:(SVHTMLContext *)context;
{
    // Use the best controller available to give us an ordered list of pagelets
    NSArrayController *controller = [context cachedSidebarPageletsController];
    if (!controller)
    {
        controller = [[SVSidebarPageletsController alloc] initWithSidebar:self];
        [controller autorelease];
    }
    
    [context addDependencyOnObject:controller keyPath:@"arrangedObjects"];
    
    
    // Write HTML
    [SVContentObject writeContentObjects:[controller arrangedObjects] inContext:context];
}

- (void)writePageletsHTML;
{
    [self writePageletsHTML:[SVHTMLContext currentContext]];
}

@end
