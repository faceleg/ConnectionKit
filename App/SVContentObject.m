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
        [context writeNewline];
    }
}

+ (void)writeContentObjects:(NSArray *)objects; // calls -writeHTML for each object
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    for (SVContentObject *anObject in objects)
    {
        [anObject writeHTML:context];
        [context writeNewline];
    }
}

#pragma mark Editing Support

- (DOMHTMLElement *)elementForEditingInDOMDocument:(DOMDocument *)document;
{
    OBPRECONDITION(document);
    
    id result = [document getElementById:[self editingElementID]];
    
    if (![result isKindOfClass:[DOMHTMLElement class]]) result = nil;
    
    return result;
}

- (BOOL)shouldPublishEditingElementID; { return NO; }

- (NSString *)editingElementID;
{
    //  The default is just to generate a string based on object address, keeping us nicely unique
    NSString *result = [NSString stringWithFormat:@"%p", self];
    return result;
}

#pragma mark Inspection

- (id)valueForUndefinedKey:(NSString *)key
{
    return NSNotApplicableMarker;
}

@end
