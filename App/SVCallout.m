//
//  SVCallout.m
//  Sandvox
//
//  Created by Mike on 27/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCallout.h"

#import "SVCalloutDOMController.h"
#import "SVHTMLTemplateParser.h"
#import "SVPagelet.h"


@implementation SVCallout

@dynamic pagelets;
- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;
{
    return [SVPagelet validatePagelets:pagelets error:error];
}

@dynamic wrap;

#pragma mark HTML

- (NSString *)HTMLString
{
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc]
                                    initWithTemplate:[[[self class] calloutHTMLTemplate] templateString]
                                    component:self];
    
    NSString *result = [parser parseTemplate];
    
    [parser release];
    return result;
}

+ (SVTemplate *)calloutHTMLTemplate;
{
    static SVTemplate *result;
    if (!result)
    {
        result = [[SVTemplate templateNamed:@"CalloutTemplate.html"] retain];
    }
    
    return result;
}

#pragma mark Editing

+ (Class)DOMControllerClass { return [SVCalloutDOMController class]; }

@end
