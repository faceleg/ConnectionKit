// 
//  SVSidebar.m
//  Sandvox
//
//  Created by Mike on 29/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSidebar.h"

#import "KTAbstractPage.h"
#import "SVHTMLTemplateParser.h"
#import "SVPagelet.h"

#import "NSSortDescriptor+Karelia.h"


@implementation SVSidebar 

@dynamic page;

#pragma mark Pagelets

@dynamic pagelets;

- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error
{
    return [SVPagelet validatePagelets:pagelets error:error];
}

#pragma mark HTML

- (void)writePageletsHTML;
{
    NSArray *pagelets = [SVPagelet arrayBySortingPagelets:[self pagelets]];
    
    // Kinda hacky, have to record a series of dependencies to handle sorting. #59554
    SVHTMLContext *context = [SVHTMLContext currentContext];
    [context addDependencyOnObject:self keyPath:@"pagelets"];
    for (SVPagelet *aPagelet in pagelets)
    {
        [context addDependencyOnObject:aPagelet keyPath:@"sortKey"];
    }
    
    // Write HTML
    [SVContentObject writeContentObjects:pagelets];
}

@end
