// 
//  SVImage.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImage.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "SVStringAttribute.h"

@implementation SVImage 

@dynamic media;

@dynamic width;
@dynamic height;

@dynamic inlineGraphic;

- (void)writeHTML
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    NSURL *imageURL = [[self media] fileURL];
    [context writeImageWithIdName:[self editingElementID] className:nil
                              src:[imageURL relativeString] alt:nil width:nil height:nil];
}

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end
