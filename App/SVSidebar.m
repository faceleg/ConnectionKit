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

#pragma mark HTML

- (NSString *)pageletsHTMLString;
{
    NSArray *pagelets = [SVPagelet arrayBySortingPagelets:[self pagelets]];
    NSArray *pageletsHTML = [pagelets valueForKey:@"HTMLString"];
    NSString *result = [pageletsHTML componentsJoinedByString:@"\n"];
    
    return result;
}

@end
