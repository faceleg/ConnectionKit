//
//  SVContentObject.m
//  Sandvox
//
//  Created by Mike on 29/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"

#import "SVDOMController.h"


@implementation SVContentObject

#pragma mark HTML

- (NSString *)HTMLString
{
    SUBCLASSMUSTIMPLEMENT;
    return nil;
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

+ (Class)DOMControllerClass;
{
    return [SVDOMController class];
}

@end
