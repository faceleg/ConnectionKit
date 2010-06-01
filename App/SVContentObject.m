//
//  SVContentObject.m
//  Sandvox
//
//  Created by Mike on 29/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVDOMController.h"
#import "SVHTMLContext.h"
#import "SVBlogSummaryDOMController.h"


@implementation SVContentObject

#pragma mark HTML

- (void)writeHTML:(SVHTMLContext *)context; // default calls -HTMLString and writes that to the current context
{    
    [context writeHTMLString:[self HTMLString]];
}

- (void)writeHTML; { [self writeHTML:[SVHTMLContext currentContext]]; }

- (NSString *)HTMLString
{
    SUBCLASSMUSTIMPLEMENT;
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (void)writeContentObjects:(NSArray *)objects inContext:(SVHTMLContext *)context;
{
    for (SVContentObject *anObject in objects)
    {
        [anObject writeHTML:context];
    }
}

+ (void)writeContentObjects:(NSArray *)objects; // calls -writeHTML for each object
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    for (SVContentObject *anObject in objects)
    {
        [anObject writeHTML:context];
    }
}

#pragma mark Editing Support

- (BOOL)shouldPublishEditingElementID; { return NO; }

- (NSString *)elementIdName; { return nil; }

#pragma mark Inspection

- (id)valueForUndefinedKey:(NSString *)key
{
    return NSNotApplicableMarker;
}

@end
