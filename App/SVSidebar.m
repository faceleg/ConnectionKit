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

- (void)writePageletsHTML;
{
    // Use the best controller available to give us an ordered list of pagelets
    SVSidebarPageletsController *pageletsController =
    [[SVSidebarPageletsController alloc] initWithSidebar:self];
    
    SVHTMLContext *context = [SVHTMLContext currentContext];
    [context addDependencyOnObject:pageletsController keyPath:@"arrangedObjects"];
    
    // Write HTML
    [SVContentObject writeContentObjects:[pageletsController arrangedObjects] inContext:context];
    [pageletsController release];
}

@end
