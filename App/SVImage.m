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
@dynamic inlineGraphic;

- (void)writeHTML
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    [context writeImageWithIdName:[self editingElementID] className:nil src:@"foo" alt:nil width:nil height:nil];
}

- (BOOL)shouldPublishEditingElementID; { return NO; }

@end
