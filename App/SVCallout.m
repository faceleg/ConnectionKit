//
//  SVCallout.m
//  Sandvox
//
//  Created by Mike on 27/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVCallout.h"

#import "SVHTMLTemplateParser.h"
#import "SVGraphic.h"


@implementation SVCallout

@dynamic pagelets;
- (BOOL)validatePagelets:(NSSet **)pagelets error:(NSError **)error;
{
    return [SVGraphic validatePagelets:pagelets error:error];
}

@dynamic wrap;

#pragma mark HTML

- (void)writeHTML
{
    SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc]
                                    initWithTemplate:[[[self class] calloutHTMLTemplate] templateString]
                                    component:self];
    
    [parser parse];
    [parser release];
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

@end
