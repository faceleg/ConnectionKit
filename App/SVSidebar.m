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
    BOOL result = YES;
    
    // All our pagelets should have unique sort keys
    NSSet *sortKeys = [*pagelets valueForKey:@"sortKey"];
    if ([sortKeys count] != [*pagelets count])
    {
        result = NO;
        if (error)
        {
            NSDictionary *info = [NSDictionary dictionaryWithObject:@"Pagelet sort keys are not unique" forKey:NSLocalizedDescriptionKey];
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSManagedObjectValidationError userInfo:info];
        }
    }
    
    return result;
}

#pragma mark HTML

- (NSString *)pageletsHTMLString;
{
    NSString *result = @"";
    
    for (SVPagelet *aPagelet in [SVPagelet arrayBySortingPagelets:[self pagelets]])
    {
        // Generate HTML for the pagelet
        NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"PageletTemplate" ofType:@"html"];
        NSString *template = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:nil];
        
        SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:template
                                                                            component:aPagelet];
        NSString *pageletHTML = [parser parseTemplate];
        result = [result stringByAppendingString:pageletHTML];
    }
    
    return result;
}

@end
